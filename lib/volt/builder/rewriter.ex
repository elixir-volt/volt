defmodule Volt.Builder.Rewriter do
  @moduledoc "Rewrites production bundle imports, workers, externals, and chunk references."

  alias Volt.Builder.Externals

  @dynamic_import_keyword "import"
  @dynamic_import_placeholder_prefix "__volt_dynamic_import__"

  def rewrite_external_imports(js_files, ctx) do
    if MapSet.size(ctx.external_set) == 0 do
      js_files
    else
      Externals.rewrite_imports(js_files, ctx.external_set, ctx.external_globals)
    end
  end

  def external_chunk_imports(js_files, chunk_import_map) do
    js_files
    |> Enum.flat_map(fn {_label, code} ->
      collect_external_chunk_imports(code, chunk_import_map)
    end)
    |> Enum.uniq()
  end

  def protect_dynamic_imports(js_files) do
    placeholder = dynamic_import_placeholder(js_files)

    protected =
      Enum.map(js_files, fn {label, code} ->
        {label, protect_dynamic_imports_in_code(code, placeholder)}
      end)

    {protected, placeholder}
  end

  def restore_dynamic_imports(code, placeholder) do
    String.replace(code, placeholder <> "(", @dynamic_import_keyword <> "(")
  end

  def inject_external_preamble(code, js_files, ctx) do
    if MapSet.size(ctx.external_set) == 0 do
      code
    else
      external_imports = Externals.collect_imports(js_files, ctx.external_set)

      if map_size(external_imports) == 0 do
        code
      else
        preamble = Externals.generate_preamble(external_imports, ctx.external_globals)
        inject_into_iife(code, preamble)
      end
    end
  end

  def rewrite_chunk_imports(code, chunk_import_map, chunk_url_map) do
    case OXC.parse(code, "chunk.js") do
      {:ok, ast} ->
        patches = collect_import_patches(ast, chunk_import_map, chunk_url_map)
        worker_patches = collect_worker_patches(code, chunk_import_map, chunk_url_map)
        all_patches = patches ++ worker_patches
        if all_patches == [], do: code, else: Volt.JS.Patch.apply(code, all_patches)

      {:error, _} ->
        code
    end
  end

  def worker_map_for_modules(module_paths, ctx) do
    module_paths
    |> Enum.flat_map(fn importer -> ctx.workers |> Map.get(importer, %{}) |> Map.to_list() end)
    |> worker_filename_map(ctx)
  end

  def all_worker_map(ctx) do
    ctx.workers
    |> Map.values()
    |> Enum.flat_map(&Map.to_list/1)
    |> worker_filename_map(ctx)
  end

  def rewrite_dynamic_preloads(code, preload_map) when preload_map == %{}, do: code

  def rewrite_dynamic_preloads(code, preload_map) do
    case OXC.parse(code, "chunk.js") do
      {:ok, ast} ->
        patches = collect_dynamic_preload_patches(ast, code, preload_map)

        if patches == [] do
          code
        else
          preload_helper() <> Volt.JS.Patch.apply(code, patches)
        end

      {:error, _} ->
        code
    end
  end

  def rewrite_worker_urls(code, worker_map, _filename) when worker_map == %{}, do: code

  def rewrite_worker_urls(code, worker_map, filename) do
    case Volt.JS.Transforms.Workers.rewrite(code, to_string(filename), fn specifier ->
           case Map.fetch(worker_map, specifier) do
             {:ok, worker_filename} -> {:rewrite, "./#{worker_filename}"}
             :error -> :keep
           end
         end) do
      {:ok, rewritten} -> rewritten
      {:error, _} -> code
    end
  end

  defp collect_dynamic_preload_patches(ast, code, preload_map) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: :import_expression, source: source, start: start, end: finish} = node, patches
        when is_integer(start) and is_integer(finish) ->
          case Volt.JS.AST.string_literal_span(source) do
            {:ok, specifier, _s, _e} ->
              case Map.get(preload_map, specifier) do
                deps when is_list(deps) and deps != [] ->
                  import_expression = binary_part(code, start, finish - start)

                  replacement = [
                    "globalThis.__voltPreload(() => ",
                    import_expression,
                    ", ",
                    Jason.encode!(deps),
                    ")"
                  ]

                  {node, [Volt.JS.Patch.new(start, finish, replacement) | patches]}

                _ ->
                  {node, patches}
              end

            nil ->
              {node, patches}
          end

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp preload_helper do
    {:volt, "ts"}
    |> Volt.Priv.path("client/preload-global.ts")
    |> Volt.JS.Runtime.Bundler.bundle_file()
    |> case do
      {:ok, code} -> code <> "\n"
      {:error, reason} -> raise "could not bundle Volt preload helper: #{inspect(reason)}"
    end
  end

  defp worker_filename_map(worker_specs, ctx) do
    worker_specs
    |> Map.new(fn {specifier, resolved_path} ->
      {specifier, Map.get(ctx.worker_results, resolved_path)}
    end)
    |> Enum.reject(fn {_specifier, filename} -> is_nil(filename) end)
    |> Map.new()
  end

  defp collect_external_chunk_imports(code, chunk_import_map) do
    case OXC.parse(code, "chunk.js") do
      {:ok, ast} ->
        {_ast, specifiers} =
          OXC.postwalk(ast, [], fn
            %{source: %{type: :literal, value: spec}} = node, specifiers
            when node.type in [
                   :import_declaration,
                   :export_named_declaration,
                   :export_all_declaration
                 ] and
                   is_binary(spec) ->
              maybe_external_chunk_specifier(node, specifiers, spec, chunk_import_map)

            %{type: :import_expression, source: %{type: :literal, value: spec}} = node, specifiers
            when is_binary(spec) ->
              maybe_external_chunk_specifier(node, specifiers, spec, chunk_import_map)

            node, specifiers ->
              {node, specifiers}
          end)

        specifiers

      {:error, _} ->
        []
    end
  end

  defp maybe_external_chunk_specifier(node, specifiers, spec, chunk_import_map) do
    if Map.has_key?(chunk_import_map, spec) do
      {node, [spec | specifiers]}
    else
      {node, specifiers}
    end
  end

  defp dynamic_import_placeholder(js_files) do
    code = Enum.map_join(js_files, "\n", fn {_label, code} -> code end)

    Stream.iterate(0, &(&1 + 1))
    |> Enum.find_value(fn suffix ->
      candidate = @dynamic_import_placeholder_prefix <> Integer.to_string(suffix) <> "__"
      if String.contains?(code, candidate), do: nil, else: candidate
    end)
  end

  defp protect_dynamic_imports_in_code(code, placeholder) do
    case OXC.parse(code, "chunk.js") do
      {:ok, ast} ->
        patches = collect_dynamic_import_protection_patches(ast, placeholder)
        if patches == [], do: code, else: Volt.JS.Patch.apply(code, patches)

      {:error, _} ->
        code
    end
  end

  defp collect_dynamic_import_protection_patches(ast, placeholder) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: :import_expression, start: start} = node, patches when is_integer(start) ->
          {node, [dynamic_import_protection_patch(start, placeholder) | patches]}

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp dynamic_import_protection_patch(start, placeholder) do
    Volt.JS.Patch.new(start, start + byte_size(@dynamic_import_keyword), placeholder)
  end

  defp collect_import_patches(ast, chunk_import_map, chunk_url_map) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: type, source: source} = node, patches
        when type in [:import_declaration, :export_named_declaration, :export_all_declaration] ->
          maybe_patch_source(node, patches, source, chunk_import_map, chunk_url_map)

        %{
          type: :import_expression,
          source: %{
            type: :template_literal,
            expressions: [],
            quasis: [%{value: %{cooked: spec}}],
            start: s,
            end: e
          }
        } = node,
        patches
        when is_binary(spec) ->
          maybe_patch_specifier(node, patches, spec, s, e, chunk_import_map, chunk_url_map)

        %{type: :import_expression, source: source} = node, patches ->
          maybe_patch_source(node, patches, source, chunk_import_map, chunk_url_map)

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp collect_worker_patches(code, chunk_import_map, chunk_url_map) do
    case OXC.select(code, "chunk.js", :workers) do
      {:ok, workers} ->
        Enum.reduce(workers, [], fn worker, patches ->
          spec = Volt.JS.Patch.selector_specifier(worker)
          maybe_patch_selector(worker, patches, spec, chunk_import_map, chunk_url_map)
        end)

      {:error, _} ->
        []
    end
  end

  defp maybe_patch_selector(selector, patches, spec, chunk_import_map, chunk_url_map) do
    with {:ok, chunk_id} <- Map.fetch(chunk_import_map, spec),
         url when is_binary(url) <- chunk_url_map[chunk_id] do
      [Volt.JS.Patch.replace_selector(selector, "'./#{url}'") | patches]
    else
      _ -> patches
    end
  end

  defp maybe_patch_source(node, patches, source, chunk_import_map, chunk_url_map) do
    case Volt.JS.AST.string_literal_span(source) do
      {:ok, spec, s, e} ->
        maybe_patch_specifier(node, patches, spec, s, e, chunk_import_map, chunk_url_map)

      nil ->
        {node, patches}
    end
  end

  defp maybe_patch_specifier(node, patches, spec, s, e, chunk_import_map, chunk_url_map) do
    {node, maybe_patch_specifier(patches, spec, s, e, chunk_import_map, chunk_url_map)}
  end

  defp maybe_patch_specifier(patches, spec, s, e, chunk_import_map, chunk_url_map) do
    with {:ok, chunk_id} <- Map.fetch(chunk_import_map, spec),
         url when is_binary(url) <- chunk_url_map[chunk_id] do
      [Volt.JS.Patch.new(s, e, "'./#{url}'") | patches]
    else
      _ -> patches
    end
  end

  defp inject_into_iife(code, preamble) do
    case find_iife_body_start(code) do
      {:ok, offset} ->
        binary_part(code, 0, offset) <>
          "\n" <> preamble <> binary_part(code, offset, byte_size(code) - offset)

      :error ->
        preamble <> code
    end
  end

  defp find_iife_body_start(code) do
    case OXC.parse(code, "iife.js") do
      {:ok, ast} ->
        {_ast, result} =
          OXC.postwalk(ast, :error, fn
            %{type: :arrow_function_expression, body: %{type: :function_body, start: start}} =
                node,
            :error ->
              {node, {:ok, start + 1}}

            node, acc ->
              {node, acc}
          end)

        result

      {:error, _} ->
        :error
    end
  end
end
