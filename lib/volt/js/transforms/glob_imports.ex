defmodule Volt.JS.Transforms.GlobImports do
  @moduledoc """
  Transforms `import.meta.glob()` calls into static import maps.

  Supported forms include lazy and eager imports, arrays of patterns, negative
  patterns, named imports, string or object `query` options, `base`, and
  TypeScript generic syntax. The transform runs after framework/plugin output is
  compiled, so glob calls emitted by SFC compilers or plugins participate in the
  same graph as source-authored calls.

  Generated import modules are built from OXC templates or encoded literals;
  avoid adding string-built JavaScript syntax unless the syntax is validated by
  the parser before use.
  """

  alias Volt.JS.{AST, Patch}

  @doc """
  Extracts static glob patterns from `import.meta.glob()` calls.

  Returns an empty list when parsing fails or no supported glob call is found.
  Patterns are returned exactly as authored, including negative patterns prefixed
  with `!`.
  """
  @spec patterns(String.t(), String.t()) :: [String.t()]
  def patterns(source, filename \\ "glob.ts") do
    case OXC.select(source, filename, :glob_imports) do
      {:ok, calls} -> Enum.flat_map(calls, & &1.patterns)
      {:error, _} -> []
    end
  end

  @doc """
  Transforms `import.meta.glob()` calls in source code.

  `base_dir` is the directory of the file containing the glob call and is used to
  resolve patterns to files. `filename` is only used for parser diagnostics.
  Returns the original source unchanged when parsing fails or no glob call is
  found.
  """
  @spec transform(String.t(), String.t(), String.t()) :: String.t()
  def transform(source, base_dir, filename \\ "glob.ts") do
    case OXC.select(source, filename, :glob_imports) do
      {:ok, []} ->
        source

      {:ok, _calls} ->
        transform_glob_calls(source, base_dir, filename)

      {:error, _} ->
        source
    end
  end

  defp transform_glob_calls(source, base_dir, filename) do
    case OXC.parse(source, filename) do
      {:ok, ast} ->
        calls = collect_glob_calls(ast)
        if calls == [], do: source, else: apply_transforms(source, calls, base_dir)

      {:error, _} ->
        source
    end
  end

  defp collect_glob_calls(ast) do
    {_ast, calls} =
      OXC.postwalk(ast, [], fn node, acc ->
        case AST.import_meta_call_arguments(node, "glob") do
          {:ok, args} -> collect_glob_call(node, args, acc)
          nil -> {node, acc}
        end
      end)

    Enum.sort_by(calls, & &1.start)
  end

  defp collect_glob_call(node, args, acc) do
    case parse_glob_args(args) do
      {:ok, call} -> {node, [%{call | start: node.start, end: node.end} | acc]}
      :skip -> {node, acc}
    end
  end

  defp parse_glob_args([pattern_node | rest]) do
    with {:ok, patterns} <- parse_patterns(pattern_node),
         {:ok, %Volt.JS.Transforms.GlobImports.Call{} = opts} <- parse_options(rest) do
      {:ok, %{opts | patterns: patterns}}
    else
      :error -> :skip
    end
  end

  defp parse_glob_args(_), do: :skip

  defp parse_patterns(%{type: :literal, value: pattern}) when is_binary(pattern),
    do: {:ok, [pattern]}

  defp parse_patterns(%{type: :array_expression, elements: elements}) do
    Enum.reduce_while(elements, {:ok, []}, fn
      %{type: :literal, value: pattern}, {:ok, acc} when is_binary(pattern) ->
        {:cont, {:ok, [pattern | acc]}}

      _node, _acc ->
        {:halt, :error}
    end)
    |> case do
      {:ok, patterns} -> {:ok, Enum.reverse(patterns)}
      :error -> :error
    end
  end

  defp parse_patterns(_node), do: :error

  defp parse_options([]), do: {:ok, %Volt.JS.Transforms.GlobImports.Call{}}

  defp parse_options([%{type: :object_expression, properties: props} | _]) do
    opts = %Volt.JS.Transforms.GlobImports.Call{}

    props
    |> Enum.reduce_while(opts, &parse_option/2)
    |> case do
      :error -> :error
      opts -> {:ok, opts}
    end
  end

  defp parse_options(_), do: :error

  defp parse_option(%{key: %{name: "eager"}, value: %{value: value}}, acc) when is_boolean(value),
    do: {:cont, %{acc | eager: value}}

  defp parse_option(%{key: %{name: "import"}, value: %{value: value}}, acc) when is_binary(value),
    do: {:cont, %{acc | import: value}}

  defp parse_option(%{key: %{name: "query"}, value: %{value: value}}, acc) when is_binary(value),
    do: {:cont, %{acc | query: normalize_query(value)}}

  defp parse_option(%{key: %{name: "query"}, value: %{type: :object_expression} = value}, acc) do
    case query_object(value) do
      {:ok, query} -> {:cont, %{acc | query: query}}
      :error -> {:halt, :error}
    end
  end

  defp parse_option(%{key: %{name: "base"}, value: %{value: value}}, acc) when is_binary(value),
    do: {:cont, %{acc | base: value}}

  defp parse_option(_property, _acc), do: {:halt, :error}

  defp query_object(%{properties: props}) do
    props
    |> Enum.reduce_while([], &query_param/2)
    |> case do
      :error -> :error
      params -> {:ok, URI.encode_query(Enum.reverse(params))}
    end
  end

  defp query_param(%{key: key, value: %{value: value}}, acc)
       when is_binary(value) or is_number(value) or is_boolean(value) do
    case AST.property_key(key) do
      {:ok, key} -> {:cont, [{key, to_string(value)} | acc]}
      :error -> {:halt, :error}
    end
  end

  defp query_param(_property, _acc), do: {:halt, :error}

  defp normalize_query(""), do: ""
  defp normalize_query("?" <> query), do: query
  defp normalize_query(query), do: query

  defp apply_transforms(source, calls, base_dir) do
    {eager_calls, lazy_calls} = Enum.split_with(calls, & &1.eager)

    eager_preamble =
      eager_calls
      |> Enum.with_index()
      |> Enum.map(fn {call, i} ->
        files = resolve_globs(call.patterns, base_dir, call.base)
        {preamble_lines(files, i * 100, call), eager_expansion(files, i * 100, call)}
      end)

    preamble =
      eager_preamble
      |> Enum.flat_map(fn {lines, _} -> lines end)
      |> Enum.intersperse("\n")

    eager_patches =
      eager_calls
      |> Enum.zip(Enum.map(eager_preamble, fn {_, expansion} -> expansion end))
      |> Enum.map(fn {call, expansion} -> Patch.new(call.start, call.end, expansion) end)

    lazy_patches =
      Enum.map(lazy_calls, fn call ->
        files = resolve_globs(call.patterns, base_dir, call.base)
        Patch.new(call.start, call.end, lazy_expansion(files, call))
      end)

    patched = Patch.apply(source, eager_patches ++ lazy_patches)

    if preamble == [] do
      patched
    else
      IO.iodata_to_binary([preamble, "\n", patched])
    end
  end

  defp resolve_globs(patterns, base_dir, base) do
    {negated, positive} = Enum.split_with(patterns, &String.starts_with?(&1, "!"))

    excluded =
      negated
      |> Enum.flat_map(fn "!" <> pattern -> wildcard(pattern, base_dir, base) end)
      |> Enum.map(& &1.specifier)
      |> MapSet.new()

    positive
    |> Enum.flat_map(&wildcard(&1, base_dir, base))
    |> Enum.reject(&MapSet.member?(excluded, &1.specifier))
    |> Enum.uniq_by(& &1.specifier)
    |> Enum.sort_by(& &1.key)
  end

  defp wildcard(pattern, base_dir, base) do
    key_base_dir = key_base_dir(base, base_dir)

    Path.join(base_dir, pattern)
    |> Path.wildcard()
    |> Enum.map(fn path ->
      %Volt.JS.Transforms.GlobImports.File{
        specifier: "./" <> Path.relative_to(path, base_dir),
        key: "./" <> Path.relative_to(path, key_base_dir)
      }
    end)
  end

  defp key_base_dir(nil, base_dir), do: base_dir
  defp key_base_dir(base, base_dir), do: Path.expand(base, base_dir)

  defp lazy_expansion(files, call) do
    files
    |> Enum.map(&lazy_entry(&1, call))
    |> object_expression()
  end

  defp preamble_lines(files, offset, call) do
    files
    |> Enum.with_index(offset)
    |> Enum.map(fn {file, i} -> import_statement("__glob_#{i}", file.specifier, call) end)
  end

  defp eager_expansion(files, offset, call) do
    files
    |> Enum.with_index(offset)
    |> Enum.map(fn {file, i} -> eager_entry(file, "__glob_#{i}", call) end)
    |> object_expression()
  end

  defp lazy_entry(file, call) do
    import_path = import_path(file.specifier, call)

    value =
      case call.import do
        nil ->
          ["() => import(", Jason.encode!(import_path), ")"]

        "*" ->
          ["() => import(", Jason.encode!(import_path), ")"]

        key ->
          [
            "() => import(",
            Jason.encode!(import_path),
            ").then((m) => m[",
            Jason.encode!(key),
            "])"
          ]
      end

    [Jason.encode!(file.key), ": ", value]
  end

  defp eager_entry(file, identifier, call) do
    value =
      case call.import do
        nil -> identifier
        "*" -> identifier
        "default" -> identifier
        _key -> identifier
      end

    [Jason.encode!(file.key), ": ", value]
  end

  defp import_path(file, %{query: ""}), do: file
  defp import_path(file, %{query: query}), do: Volt.URL.append_query(file, query)

  defp object_expression(entries) do
    ast =
      "const __glob = { $entries };"
      |> OXC.parse!("glob-object-template.js")
      |> OXC.splice(:entries, entries)

    ast
    |> OXC.codegen!()
    |> String.trim()
    |> String.trim_leading("const __glob = ")
    |> String.trim_trailing(";")
  end

  defp import_statement(identifier, specifier, call) do
    import = call.import || "*"

    import
    |> import_template()
    |> OXC.parse!("glob-import-template.js")
    |> OXC.bind(identifier: identifier)
    |> maybe_bind_import_key(import)
    |> AST.replace_literal("__specifier__", import_path(specifier, call))
    |> OXC.codegen!()
    |> String.trim()
  end

  defp import_template("*"), do: "import * as $identifier from \"__specifier__\";"
  defp import_template("default"), do: "import $identifier from \"__specifier__\";"
  defp import_template(_key), do: "import { $key as $identifier } from \"__specifier__\";"

  defp maybe_bind_import_key(ast, import) when import in ["*", "default"], do: ast
  defp maybe_bind_import_key(ast, key), do: OXC.bind(ast, key: key)
end
