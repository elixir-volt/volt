defmodule Volt.Builder.Plan do
  @moduledoc false

  alias Volt.Builder.Artifact

  @enforce_keys [:artifacts]
  defstruct [:artifacts]

  @type t :: %__MODULE__{artifacts: [Artifact.t()]}

  @spec new([Artifact.t()]) :: {:ok, t()} | {:error, term()}
  def new(artifacts) do
    artifacts
    |> Enum.reduce_while({:ok, %{}}, fn %Artifact{} = artifact, {:ok, files} ->
      cond do
        not safe_path?(artifact.file) ->
          {:halt, {:error, {:invalid_output_path, artifact.file}}}

        Map.has_key?(files, artifact.file) and files[artifact.file] != artifact ->
          {:halt, {:error, {:output_collision, artifact.file}}}

        true ->
          {:cont, {:ok, Map.put(files, artifact.file, artifact)}}
      end
    end)
    |> case do
      {:ok, files} -> {:ok, %__MODULE__{artifacts: Enum.sort_by(Map.values(files), & &1.file)}}
      {:error, _} = error -> error
    end
  end

  @doc "Validate manifest identities and emitted file references against a prepared plan."
  def validate_manifest(%__MODULE__{artifacts: artifacts}, manifest) do
    files = MapSet.new(artifacts, & &1.file)

    errors =
      Enum.flat_map(manifest, fn {key, %Volt.Builder.ManifestEntry{} = entry} ->
        missing_keys =
          for reference <- entry.imports ++ entry.dynamicImports,
              not Map.has_key?(manifest, reference),
              do: {:missing_manifest_entry, key, reference}

        missing_files =
          for file <- [entry.file | entry.css ++ entry.assets],
              not MapSet.member?(files, file),
              do: {:missing_artifact, key, file}

        missing_keys ++ missing_files
      end)
      |> Enum.uniq()
      |> Enum.sort()

    case errors do
      [] -> :ok
      errors -> {:error, {:invalid_manifest, errors}}
    end
  end

  defp safe_path?(path) when is_binary(path) do
    parts = Path.split(path)

    path != "" and Path.type(path) == :relative and
      not String.contains?(path, ["\\", ":", <<0>>]) and
      Enum.all?(parts, &(&1 not in [".", ".."])) and
      Path.join(parts) == path
  end

  defp safe_path?(_path), do: false
end
