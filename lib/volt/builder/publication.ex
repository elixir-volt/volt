defmodule Volt.Builder.Publication do
  @moduledoc "Staged asset publication with manifest-last installation, not a whole-directory transaction."

  alias Volt.Builder.Plan

  @spec write(String.t(), Plan.t()) :: :ok | {:error, term()}
  def write(outdir, %Plan{} = plan) do
    root = Path.expand(outdir)
    lock = {{__MODULE__, root}, self()}
    :global.trans(lock, fn -> publish(root, plan) end, [node()])
  end

  defp publish(root, plan) do
    with :ok <- validate_destinations(root, plan.artifacts),
         :ok <- File.mkdir_p(Path.dirname(root)),
         {:ok, stage} <- create_stage(root, 10) do
      try do
        with :ok <- stage_files(stage, plan.artifacts),
             :ok <- validate_destinations(root, plan.artifacts) do
          install(root, stage, plan.artifacts)
        end
      after
        File.rm_rf(stage)
      end
    end
  end

  defp create_stage(_root, 0), do: {:error, :staging_name_exhausted}

  defp create_stage(root, attempts) do
    stage =
      root <> ".volt-stage-" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)

    case File.mkdir(stage) do
      :ok -> {:ok, stage}
      {:error, :eexist} -> create_stage(root, attempts - 1)
      {:error, reason} -> {:error, {:staging_directory_failed, reason}}
    end
  end

  defp validate_destinations(root, artifacts) do
    paths =
      Enum.flat_map(artifacts, fn artifact ->
        {_path, paths} =
          Enum.reduce(Path.split(artifact.file), {root, [root]}, fn part, {parent, paths} ->
            path = Path.join(parent, part)
            {path, [path | paths]}
          end)

        paths
      end)

    paths
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn path, :ok ->
      case File.lstat(path) do
        {:ok, %{type: :symlink}} -> {:halt, {:error, {:symlink_destination, path}}}
        {:ok, _} -> {:cont, :ok}
        {:error, reason} when reason in [:enoent, :enotdir] -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:destination_check_failed, path, reason}}}
      end
    end)
  end

  defp stage_files(stage, artifacts) do
    Enum.reduce_while(artifacts, :ok, fn artifact, :ok ->
      path = Path.join(stage, artifact.file)

      case write_file(path, artifact.content) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:staging_failed, artifact.file, reason}}}
      end
    end)
  end

  defp write_file(path, content) do
    with :ok <- File.mkdir_p(Path.dirname(path)), do: File.write(path, content)
  end

  defp install(root, stage, artifacts) do
    artifacts
    |> Enum.sort_by(fn artifact ->
      {Path.basename(artifact.file) == "manifest.json", artifact.file}
    end)
    |> Enum.reduce_while(:ok, fn artifact, :ok ->
      destination = Path.join(root, artifact.file)

      result =
        with :ok <- File.mkdir_p(Path.dirname(destination)),
             do: File.rename(Path.join(stage, artifact.file), destination)

      case result do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:publication_failed, artifact.file, reason}}}
      end
    end)
  end
end
