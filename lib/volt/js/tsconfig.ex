defmodule Volt.JS.TSConfig do
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
  The first path in each mapping array that is not a declaration file is used;
  mappings that only point at declaration files (`.d.ts`) describe types and
  are left to normal module resolution.
  """
  @spec read_paths(String.t()) :: %{String.t() => String.t()}
  def read_paths(tsconfig_path) do
    with {:ok, content} <- File.read(tsconfig_path),
         {:ok, json} <- Jason.decode(content),
         %{"compilerOptions" => %{"paths" => paths}} when is_map(paths) <- json do
      base_url = get_in(json, ["compilerOptions", "baseUrl"]) || "."
      tsconfig_dir = Path.dirname(tsconfig_path)
      base = Path.expand(base_url, tsconfig_dir)

      for {key, targets} <- paths,
          target = Enum.find(List.wrap(targets), &runtime_target?/1),
          into: %{} do
        {trim_glob(key), Path.expand(trim_glob(target), base)}
      end
    else
      _ -> %{}
    end
  end

  defp runtime_target?(target) when is_binary(target) do
    not String.ends_with?(target, [".d.ts", ".d.mts", ".d.cts"])
  end

  defp runtime_target?(_target), do: false

  defp trim_glob(pattern) do
    pattern
    |> String.trim_trailing("/*")
    |> String.trim_trailing("*")
    |> String.trim_trailing("/")
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
end
