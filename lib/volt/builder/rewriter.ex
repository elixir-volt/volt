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

  def rewrite_dynamic_imports(code, module_to_chunk, chunk_url_map) do
    case OXC.collect_dynamic_refs(code, "chunk.js") do
      {:ok, refs} ->
        patches =
          Enum.flat_map(refs, fn %{specifier: spec, start: s, end: e} ->
            case find_chunk_url(spec, module_to_chunk, chunk_url_map) do
              nil -> []
              url -> [%{start: s, end: e, change: "'./#{url}'"}]
            end
          end)

        if patches == [], do: code, else: OXC.patch_string(code, patches)

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

  defp find_chunk_url(spec, module_to_chunk, chunk_url_map) do
    spec_normalized =
      spec
      |> String.trim_leading("./")
      |> String.trim_leading("../")
      |> Path.rootname()

    chunk_id =
      Enum.find_value(module_to_chunk, fn {mod_path, chunk_id} ->
        mod_normalized = Path.rootname(mod_path)

        if String.ends_with?(mod_normalized, spec_normalized) do
          chunk_id
        end
      end)

    if chunk_id, do: chunk_url_map[chunk_id]
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
    case OXC.find_iife_body_offset(code, "iife.js") do
      {:ok, offset} -> {:ok, offset}
      {:error, _} -> :error
    end
  end
end
