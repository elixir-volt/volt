defmodule Volt.JS.Lint.TSConfigOverlay do
  @moduledoc """
  Puts virtual modules, such as the scripts of a `.vue` file, into the TypeScript
  project that covers them.

  tsgolint assigns a file to a project by the nearest `tsconfig.json` that
  includes it, and expands `include` by listing directories on disk. A virtual
  module is not on disk, so it lands in an inferred project with default
  options: the project's `paths` do not apply to it, and the declaration files
  the project includes are not in its program.

  tsgolint does read file contents, and a `tsconfig.json` among them, through
  the same overrides that carry the virtual modules. So the nearest
  `tsconfig.json` is overridden with one that extends the original and names
  the virtual modules in `files`. The original is carried unchanged under
  another name beside it, so relative paths in it keep their meaning.
  """

  @base "tsconfig.volt-base.json"

  @doc """
  Return the source overrides that add `virtual_files` to their projects.

  A virtual module without a `tsconfig.json` above it, or whose `tsconfig.json`
  cannot be read as an object, is left to the inferred project.
  """
  @spec overrides([String.t()]) :: %{String.t() => String.t()}
  def overrides(virtual_files) do
    virtual_files
    |> Enum.group_by(&nearest_tsconfig(Path.dirname(&1)))
    |> Enum.flat_map(fn
      {nil, _files} -> []
      {tsconfig, files} -> project(tsconfig, Enum.sort(files))
    end)
    |> Map.new()
  end

  defp nearest_tsconfig(dir) do
    tsconfig = Path.join(dir, "tsconfig.json")
    parent = Path.dirname(dir)

    cond do
      File.regular?(tsconfig) -> tsconfig
      parent == dir -> nil
      true -> nearest_tsconfig(parent)
    end
  end

  defp project(tsconfig, virtual_files) do
    with {:ok, source} <- File.read(tsconfig),
         {:ok, properties} <- properties(source) do
      [
        {Path.join(Path.dirname(tsconfig), @base), source},
        {tsconfig, Jason.encode!(extending(properties, virtual_files))}
      ]
    else
      _unreadable -> []
    end
  end

  # `files` in a config replaces the `files` of the config it extends, and a
  # config with `files` and no `include` includes nothing else. So the original's
  # own `files` are repeated, and the default `include` is spelled out when the
  # original relied on it.
  defp extending(properties, virtual_files) do
    config = %{
      "extends" => "./" <> @base,
      "files" => string_elements(properties["files"]) ++ virtual_files
    }

    if Enum.any?(["files", "include", "extends"], &Map.has_key?(properties, &1)),
      do: config,
      else: Map.put(config, "include", ["**/*"])
  end

  # A tsconfig may have comments and trailing commas, which makes it a
  # JavaScript object literal rather than JSON.
  defp properties(source) do
    case OXC.parse("(" <> source <> "\n)", "tsconfig.js") do
      {:ok, %{body: [%{expression: %{expression: %{type: :object_expression} = object}}]}} ->
        properties =
          for %{key: key, value: value} <- object.properties,
              {:ok, name} <- [Volt.JS.AST.property_key(key)],
              into: %{},
              do: {name, value}

        {:ok, properties}

      _other ->
        :error
    end
  end

  defp string_elements(%{type: :array_expression, elements: elements}) do
    for %{type: :literal, value: value} <- elements, is_binary(value), do: value
  end

  defp string_elements(_absent), do: []
end
