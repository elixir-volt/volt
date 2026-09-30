defmodule Volt.JS.Lint.Config do
  @moduledoc """
  Resolves lint options for a source file without reading the filesystem.

  Plugin, rule, environment, and global names are strings, as in an oxlint
  config file.

  Override globs are relative to the lint discovery root. Every matching override
  is applied in declaration order; later entries replace individual rules,
  environments and globals, not their entire maps. Environment lists enable
  names; environment maps can also disable inherited names.
  """

  @enforce_keys [:root, :options, :overrides]
  defstruct [:root, :options, :overrides]

  @type t :: %__MODULE__{
          root: String.t(),
          options: keyword(),
          overrides: [{[GlobEx.t()], keyword()}]
        }

  @doc "Compiles a lint configuration, using the build root unless lint sets its own root."
  @spec new(keyword(), String.t()) :: t()
  def new(config, root) do
    options =
      [plugins: ["typescript"], custom_rules: [], fix: false]
      |> Keyword.merge(Keyword.take(config, [:plugins, :custom_rules, :fix]))
      |> Keyword.merge(maps(config))

    names!(options[:plugins], :plugins)

    overrides =
      Enum.map(Keyword.get(config, :overrides, []), fn override ->
        override = Map.new(override)
        unknown = Map.keys(override) -- [:files, :rules, :env, :globals]

        if unknown != [] do
          raise ArgumentError, "unsupported lint override keys: #{inspect(unknown)}"
        end

        globs =
          case Map.fetch(override, :files) do
            {:ok, [_ | _] = files} ->
              Enum.map(files, &compile_glob!/1)

            _ ->
              raise ArgumentError,
                    "lint override :files must be a non-empty list of relative globs"
          end

        {globs, maps(Map.to_list(override))}
      end)

    %__MODULE__{
      root: Path.expand(Keyword.get(config, :root, root)),
      options: options,
      overrides: overrides
    }
  end

  @doc "Returns effective OXC syntax-lint options for the original source path."
  @spec options(t(), String.t()) :: keyword()
  def options(%__MODULE__{} = config, file) do
    relative = file |> Path.expand() |> Path.relative_to(config.root)

    if Path.type(relative) == :relative and List.first(Path.split(relative)) != ".." do
      relative = relative |> Path.split() |> Enum.join("/")

      config.overrides
      |> Enum.reduce(config.options, &apply_override(&1, relative, &2))
      |> enabled_environments()
    else
      enabled_environments(config.options)
    end
  end

  defp enabled_environments(options) do
    Keyword.update!(options, :env, fn env -> for {name, true} <- env, do: name end)
  end

  defp apply_override({globs, options}, relative, inherited) do
    if Enum.any?(globs, &GlobEx.match?(&1, relative)) do
      Keyword.merge(inherited, options, fn _key, base, override -> Map.merge(base, override) end)
    else
      inherited
    end
  end

  defp maps(config) do
    [
      rules: named!(Keyword.get(config, :rules, %{}), :rules),
      globals: named!(Keyword.get(config, :globals, %{}), :globals),
      env: environments!(Keyword.get(config, :env, []))
    ]
  end

  defp environments!(env) when is_list(env), do: env |> names!(:env) |> Map.new(&{&1, true})
  defp environments!(env) when is_map(env), do: named!(env, :env)

  defp named!(map, key) when is_map(map) do
    names!(Map.keys(map), key)
    map
  end

  defp names!(names, key) do
    unless is_list(names) and Enum.all?(names, &is_binary/1) do
      raise ArgumentError, "lint #{inspect(key)} names must be strings, got: #{inspect(names)}"
    end

    names
  end

  defp compile_glob!(pattern) when is_binary(pattern) do
    if Path.type(pattern) != :relative or ".." in Path.split(pattern) do
      raise ArgumentError,
            "lint override globs must stay relative to the lint root: #{inspect(pattern)}"
    end

    pattern
    |> Path.split()
    |> Enum.reject(&(&1 == "."))
    |> Enum.join("/")
    |> GlobEx.compile!(match_dot: true)
  end

  defp compile_glob!(pattern) do
    raise ArgumentError, "lint override glob must be a string, got: #{inspect(pattern)}"
  end
end
