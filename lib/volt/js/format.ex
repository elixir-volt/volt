defmodule Volt.JS.Format do
  @moduledoc false

  @config_files ~w(.oxfmtrc.json .oxfmtrc .prettierrc.json .prettierrc)

  @key_mapping %{
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

  def load_config do
    case find_config_file() do
      nil -> []
      path -> parse_config(path)
    end
  end

  defp find_config_file do
    Enum.find_value(@config_files, fn name ->
      path = Path.join(File.cwd!(), name)
      if File.exists?(path), do: path
    end)
  end

  defp parse_config(path) do
    path
    |> File.read!()
    |> Jason.decode!()
    |> Enum.flat_map(fn {key, value} ->
      case Map.get(@key_mapping, key) do
        nil -> []
        opt_key -> [{opt_key, cast_value(opt_key, value)}]
      end
    end)
  end

  defp cast_value(key, value) when key in @atom_values and is_binary(value) do
    value |> String.replace("-", "_") |> String.to_atom()
  end

  defp cast_value(_key, value), do: value
end
