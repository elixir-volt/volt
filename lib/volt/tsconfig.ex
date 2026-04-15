defmodule Volt.TSConfig do
  @moduledoc """
  Read `compilerOptions.paths` from `tsconfig.json` and convert to Volt aliases.

  Automatically discovers `tsconfig.json` in the project root and maps
  TypeScript path aliases (e.g. `"@/*": ["./src/*"]`) to the format
  Volt's resolver expects.
  """

  @doc """
  Read path aliases from tsconfig.json.

  Returns a map of alias prefix to filesystem path, e.g.:

      %{"@" => "/absolute/path/to/src"}

  Glob suffixes (`/*`) are stripped from both keys and values.
  Only the first path in each mapping array is used.
  """
  @spec read_paths(String.t()) :: %{String.t() => String.t()}
  def read_paths(tsconfig_path) do
    with {:ok, content} <- File.read(tsconfig_path),
         {:ok, json} <- decode(content),
         %{"compilerOptions" => %{"paths" => paths}} when is_map(paths) <- json do
      base_url = get_in(json, ["compilerOptions", "baseUrl"]) || "."
      tsconfig_dir = Path.dirname(tsconfig_path)
      base = Path.expand(base_url, tsconfig_dir)

      Map.new(paths, fn {key, targets} ->
        alias_key = key |> String.trim_trailing("/*") |> String.trim_trailing("*")
        alias_key = String.trim_trailing(alias_key, "/")

        target =
          targets
          |> List.first("")
          |> String.trim_trailing("/*")
          |> String.trim_trailing("*")
          |> String.trim_trailing("/")

        {alias_key, Path.expand(target, base)}
      end)
    else
      _ -> %{}
    end
  end

  @doc """
  Find and read tsconfig.json paths from the current working directory.
  """
  @spec discover_paths() :: %{String.t() => String.t()}
  def discover_paths do
    path = Path.expand("tsconfig.json")

    if File.regular?(path) do
      read_paths(path)
    else
      %{}
    end
  end

  defp decode(content) do
    {:ok, :json.decode(content)}
  rescue
    _ -> :error
  end
end
