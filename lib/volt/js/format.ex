defmodule Volt.JS.Format do
  @moduledoc "Loads JavaScript formatter configuration for oxfmt."

  @json_config_files ~w(.oxfmtrc.json .oxfmtrc .prettierrc.json .prettierrc)

  @json_key_mapping %{
    "printWidth" => :print_width,
    "tabWidth" => :tab_width,
    "useTabs" => :use_tabs,
    "semi" => :semi,
    "singleQuote" => :single_quote,
    "jsxSingleQuote" => :jsx_single_quote,
    "trailingComma" => :trailing_comma,
    "bracketSpacing" => :bracket_spacing,
    "bracketSameLine" => :bracket_same_line,
    "arrowParens" => :arrow_parens,
    "endOfLine" => :end_of_line,
    "quoteProps" => :quote_props,
    "singleAttributePerLine" => :single_attribute_per_line,
    "objectWrap" => :object_wrap,
    "experimentalOperatorPosition" => :experimental_operator_position,
    "experimentalTernaries" => :experimental_ternaries,
    "embeddedLanguageFormatting" => :embedded_language_formatting
  }

  @atom_values ~w(trailing_comma arrow_parens end_of_line quote_props object_wrap experimental_operator_position embedded_language_formatting)a
  @discovery_keys ~w(root sources ignore)a

  @dot_formatter ".formatter.exs"

  @doc """
  Load oxfmt options.

  Options come from the `:volt` key of `.formatter.exs`:

      [
        plugins: [Volt.Formatter],
        volt: [semi: false, single_quote: true]
      ]

  Without that key, they come from `.oxfmtrc.json` or `.prettierrc.json`.
  `formatter_opts` is the keyword list `.formatter.exs` evaluates to; `mix format`
  passes it to `Volt.Formatter`, and the Mix tasks read the file themselves.
  """
  @spec load_config(keyword()) :: keyword()
  def load_config(formatter_opts \\ formatter_opts()) do
    reject_application_config!(Application.get_env(:volt, :format))

    case Keyword.fetch(formatter_opts, :volt) do
      {:ok, opts} -> Keyword.drop(opts, @discovery_keys)
      :error -> load_json_config()
    end
  end

  @doc "Read the options in the project's `.formatter.exs`, or `[]` without one."
  @spec formatter_opts() :: keyword()
  def formatter_opts do
    if File.regular?(@dot_formatter) do
      {opts, _binding} = Code.eval_file(@dot_formatter)
      opts
    else
      []
    end
  end

  @doc """
  File-discovery options (`:root`, `:sources`, `:ignore`) for `mix volt.js.format`
  and `mix volt.js.check`, from the `:volt` key of `.formatter.exs`.
  """
  @spec discovery_config(keyword()) :: keyword()
  def discovery_config(formatter_opts \\ formatter_opts()) do
    formatter_opts |> Keyword.get(:volt, []) |> Keyword.take(@discovery_keys)
  end

  @doc false
  def reject_application_config!(format) when is_list(format) do
    raise ArgumentError, """
    formatter options are no longer read from `config :volt, :format`, which now \
    only holds the build output format (`:iife`, `:esm`, or `:cjs`).

    Move them to the `:volt` key of .formatter.exs:

        [
          plugins: [Volt.Formatter],
          volt: #{inspect(format)}
        ]
    """
  end

  def reject_application_config!(_format), do: :ok

  def load_json_config do
    case find_json_config() do
      nil -> []
      path -> parse_json_config(path)
    end
  end

  def format_files(files, opts \\ load_config()) do
    changed =
      Enum.count(files, fn file ->
        source = File.read!(file)
        formatted = OXC.Format.run!(source, file, opts)

        if formatted != source do
          File.write!(file, formatted)
          true
        else
          false
        end
      end)

    %{changed: changed, total: length(files)}
  end

  defp find_json_config do
    root = File.cwd!()

    search_dirs = [
      root,
      Path.join(root, Volt.Paths.assets())
    ]

    Enum.find_value(search_dirs, fn dir ->
      Enum.find_value(@json_config_files, fn name ->
        path = Path.join(dir, name)
        if File.exists?(path), do: path
      end)
    end)
  end

  defp parse_json_config(path) do
    path
    |> File.read!()
    |> Jason.decode!()
    |> Enum.flat_map(fn {key, value} ->
      case Map.get(@json_key_mapping, key) do
        nil -> []
        opt_key -> [{opt_key, cast_value(opt_key, value)}]
      end
    end)
  end

  defp cast_value(key, value) when key in @atom_values and is_binary(value) do
    value |> String.replace("-", "_") |> String.to_existing_atom()
  end

  defp cast_value(_key, value), do: value
end
