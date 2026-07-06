defmodule Volt.Plugin.Vue do
  @behaviour Volt.Plugin

  @impl true
  def name, do: "vue"

  @impl true
  def extensions(kind) when kind in [:compile, :resolve, :watch, :scan], do: [".vue"]
  def extensions(_kind), do: []

  @impl true
  def define(_mode) do
    %{
      "__VUE_OPTIONS_API__" => "true",
      "__VUE_PROD_DEVTOOLS__" => "false",
      "__VUE_PROD_HYDRATION_MISMATCH_DETAILS__" => "false"
    }
  end

  @impl true
  def compile(path, source, opts) do
    {base_path, query} = Volt.URL.split_query(path)

    if query == "" and Path.extname(base_path) == ".vue" do
      sfc_opts = [
        filename: Path.basename(path),
        vapor: Keyword.get(opts, :vapor, false),
        strip_types: true,
        custom_renderer: Keyword.get(opts, :custom_renderer, false)
      ]

      case Vize.compile_sfc(source, sfc_opts) do
        {:ok, result} ->
          {:ok,
           %Volt.Pipeline.Result{
             code: maybe_append_style_imports(result.code, path, source, opts),
             sourcemap: nil,
             css: result.css,
             hashes: %Volt.Pipeline.Result.Hashes{
               template: result.template_hash,
               style: result.style_hash,
               script: result.script_hash
             }
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def extract_imports(path, source, _opts) do
    if Path.extname(path) == ".vue" do
      {:ok,
       %Volt.JS.ImportExtractor.Result{
         imports: source |> imports() |> Enum.map(&{:static, &1}),
         workers: []
       }}
    end
  end

  @impl true
  def embedded_modules(path, source, _opts) do
    {base_path, _query} = Volt.URL.split_query(path)

    if Path.extname(base_path) == ".vue" do
      scripts(source) ++ styles(source)
    end
  end

  defp maybe_append_style_imports(code, path, source, opts) do
    if Keyword.get(opts, :mode) == :development do
      style_imports =
        path
        |> embedded_modules(source, opts)
        |> Volt.Plugin.EmbeddedModule.normalize_all()
        |> Enum.filter(&(&1.type == :style))
        |> Enum.map_join("", fn module ->
          "\nimport #{inspect(Volt.Plugin.EmbeddedModule.specifier(path, module))};"
        end)

      code <> style_imports
    else
      code
    end
  end

  defp imports(source), do: source |> scripts() |> Enum.flat_map(&script_imports/1)

  defp scripts(source) do
    case Vize.parse_sfc(source) do
      {:ok, descriptor} ->
        [descriptor.script, descriptor.script_setup]
        |> Enum.reject(&is_nil/1)
        |> Enum.map(fn block -> {script_extension(block[:lang]), block.content} end)

      {:error, _} ->
        []
    end
  end

  defp script_imports({extension, content}) do
    case OXC.select(content, "script#{extension}", :import_specifiers) do
      {:ok, imports} -> imports
      {:error, _} -> []
    end
  end

  defp styles(source) do
    case Vize.parse_sfc(source) do
      {:ok, descriptor} ->
        descriptor.styles
        |> Enum.map(fn block ->
          %Volt.Plugin.EmbeddedModule{
            type: :style,
            extension: style_extension(block[:lang]),
            source: block.content
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp script_extension("ts"), do: ".ts"
  defp script_extension("tsx"), do: ".tsx"
  defp script_extension(_lang), do: ".js"

  defp style_extension(lang) when lang in [nil, "css"], do: ".css"
  defp style_extension(lang), do: ".#{lang}"
end
