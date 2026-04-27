defmodule Volt.Builder.Rewriter do
  @moduledoc false

  alias Volt.Builder.Externals

  def rewrite_external_imports(js_files, ctx) do
    if MapSet.size(ctx.external_set) == 0 do
      js_files
    else
      Externals.rewrite_imports(js_files, ctx.external_set, ctx.external_globals)
    end
  end

  def external_chunk_imports(js_files, module_to_chunk, current_chunk_id) do
    js_files
    |> Enum.flat_map(fn {_label, code} ->
      collect_external_chunk_imports(code, module_to_chunk, current_chunk_id)
    end)
    |> Enum.uniq()
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

  def rewrite_chunk_imports(code, module_to_chunk, chunk_url_map) do
    case OXC.parse(code, "chunk.js") do
      {:ok, ast} ->
        patches = collect_import_patches(ast, module_to_chunk, chunk_url_map)
        worker_patches = collect_worker_patches(ast, module_to_chunk, chunk_url_map)
        all_patches = patches ++ worker_patches
        if all_patches == [], do: code, else: OXC.patch_string(code, all_patches)

      {:error, _} ->
        code
    end
  end

  def entry_worker_map(js_files, ctx) do
    importers = Enum.map(js_files, fn {label, _code} -> label end)

    ctx.workers
    |> Enum.filter(fn {importer, _} -> Path.basename(importer) in importers end)
    |> Enum.flat_map(fn {_importer, spec_map} -> Map.to_list(spec_map) end)
    |> Map.new(fn {specifier, resolved_path} ->
      {specifier, Map.get(ctx.worker_results, resolved_path)}
    end)
    |> Enum.reject(fn {_specifier, filename} -> is_nil(filename) end)
    |> Map.new()
  end

  def rewrite_worker_urls(code, worker_map, _filename) when worker_map == %{}, do: code

  def rewrite_worker_urls(code, worker_map, filename) do
    case Volt.JS.WorkerRewriter.rewrite(code, to_string(filename), fn specifier ->
           case Map.fetch(worker_map, specifier) do
             {:ok, worker_filename} -> {:rewrite, "./#{worker_filename}"}
             :error -> :keep
           end
         end) do
      {:ok, rewritten} -> rewritten
      {:error, _} -> code
    end
  end

  defp collect_external_chunk_imports(code, module_to_chunk, current_chunk_id) do
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
              maybe_external_chunk_specifier(
                node,
                specifiers,
                spec,
                module_to_chunk,
                current_chunk_id
              )

            %{type: :import_expression, source: %{type: :literal, value: spec}} = node, specifiers
            when is_binary(spec) ->
              maybe_external_chunk_specifier(
                node,
                specifiers,
                spec,
                module_to_chunk,
                current_chunk_id
              )

            node, specifiers ->
              {node, specifiers}
          end)

        specifiers

      {:error, _} ->
        []
    end
  end

  defp maybe_external_chunk_specifier(node, specifiers, spec, module_to_chunk, current_chunk_id) do
    if external_chunk_import?(spec, module_to_chunk, current_chunk_id) do
      {node, [spec | specifiers]}
    else
      {node, specifiers}
    end
  end

  defp external_chunk_import?(spec, module_to_chunk, current_chunk_id) do
    case find_chunk_id(spec, module_to_chunk) do
      nil -> false
      ^current_chunk_id -> false
      _chunk_id -> true
    end
  end

  defp collect_import_patches(ast, module_to_chunk, chunk_url_map) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{source: %{type: :literal, value: spec, start: s, end: e}} = node, patches
        when node.type in [
               :import_declaration,
               :export_named_declaration,
               :export_all_declaration
             ] and
               is_binary(spec) ->
          maybe_patch_specifier(node, patches, spec, s, e, module_to_chunk, chunk_url_map)

        %{type: :import_expression, source: %{type: :literal, value: spec, start: s, end: e}} =
            node,
        patches
        when is_binary(spec) ->
          maybe_patch_specifier(node, patches, spec, s, e, module_to_chunk, chunk_url_map)

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp collect_worker_patches(ast, module_to_chunk, chunk_url_map) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{
          type: :new_expression,
          callee: %{type: :identifier, name: worker_type},
          arguments: [first_arg | _]
        } = node,
        patches
        when worker_type in ["Worker", "SharedWorker"] ->
          case Volt.JS.WorkerRewriter.extract_specifier(first_arg) do
            {:ok, spec, s, e} ->
              maybe_patch_specifier(node, patches, spec, s, e, module_to_chunk, chunk_url_map)

            nil ->
              {node, patches}
          end

        node, patches ->
          {node, patches}
      end)

    patches
  end

  defp maybe_patch_specifier(node, patches, spec, s, e, module_to_chunk, chunk_url_map) do
    case find_chunk_url(spec, module_to_chunk, chunk_url_map) do
      nil -> {node, patches}
      url -> {node, [%{start: s, end: e, change: "'./#{url}'"} | patches]}
    end
  end

  defp find_chunk_url(spec, module_to_chunk, chunk_url_map) do
    case find_chunk_id(spec, module_to_chunk) do
      nil -> nil
      chunk_id -> chunk_url_map[chunk_id]
    end
  end

  defp find_chunk_id(spec, module_to_chunk) do
    spec_normalized =
      spec
      |> String.trim_leading("./")
      |> String.trim_leading("../")
      |> Path.rootname()

    Enum.find_value(module_to_chunk, fn {mod_path, chunk_id} ->
      mod_normalized = Path.rootname(mod_path)

      if String.ends_with?(mod_normalized, spec_normalized) do
        chunk_id
      end
    end)
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
