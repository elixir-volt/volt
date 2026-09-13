defmodule Volt.Plugin.Vue do
  @behaviour Volt.Plugin

  alias Vize.SFC

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
      scope_id = SFC.scope_id(base_path)

      sfc_opts = [
        scope_id: scope_id,
        filename: base_path,
        vapor: Keyword.get(opts, :vapor, false),
        strip_types: true,
        custom_renderer: Keyword.get(opts, :custom_renderer, false),
        source_map: Keyword.get(opts, :sourcemap, true)
      ]

      with {:ok, descriptor} <- Vize.parse_sfc(source),
           {:ok, assets} <- SFC.collect_template_assets(source, filename: base_path),
           {:ok, result} <- Vize.compile_sfc(source, sfc_opts) do
        assembled =
          result.code
          |> assemble_template_component(descriptor, sfc_opts[:vapor])
          |> attach_scope(descriptor, scope_id, sfc_opts[:vapor])

        {:ok,
         %Volt.Pipeline.Result{
           code:
             assembled
             |> SFC.rewrite_asset_references(assets)
             |> append_template_asset_imports(assets)
             |> maybe_append_style_imports(path, source, opts),
           sourcemap: if(assembled == result.code, do: result.source_map),
           css: result.css,
           hashes: %Volt.Pipeline.Result.Hashes{
             template: result.template_hash,
             style: result.style_hash,
             script: result.script_hash
           }
         }}
      end
    end
  end

  defp assemble_template_component(
         code,
         %{script: nil, script_setup: nil, template: template},
         false
       )
       when not is_nil(template), do: code <> "\nexport default { render };\n"

  defp assemble_template_component(code, _descriptor, _vapor), do: code

  defp attach_scope(code, %{styles: styles}, scope_id, false) do
    if Enum.any?(styles, & &1.scoped) do
      {:ok, %{body: nodes}} = OXC.parse(code, "component.js")

      patches =
        for %{type: :export_default_declaration, declaration: declaration} <- nodes do
          %{start: first, end: last} = declaration
          expression = binary_part(code, first, last - first)

          value =
            "Object.assign(#{expression}, { __scopeId: #{Jason.encode!("data-v-" <> scope_id)} })"

          Volt.JS.Patch.new(first, last, value)
        end

      Volt.JS.Patch.apply(code, patches)
    else
      code
    end
  end

  defp attach_scope(code, _descriptor, _scope_id, _vapor), do: code

  @impl true
  def extract_imports(path, source, _opts) do
    if Path.extname(path) == ".vue" do
      with {:ok, assets} <- Vize.SFC.collect_template_assets(source, filename: path) do
        {:ok,
         %Volt.JS.ImportExtractor.Result{
           imports: source |> imports(assets) |> Enum.map(&{:static, &1}),
           workers: []
         }}
      end
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
        |> Enum.map(&style_import(path, &1))

      IO.iodata_to_binary([code | style_imports])
    else
      code
    end
  end

  defp append_template_asset_imports(code, assets) do
    imports = Enum.map(assets, &template_asset_import/1)
    IO.iodata_to_binary([code | imports])
  end

  defp template_asset_import(asset) do
    "import $name from \"__specifier__\";"
    |> OXC.parse!("vue-template-asset-import.ts")
    |> OXC.bind(name: asset.binding)
    |> Volt.JS.AST.replace_literal("__specifier__", asset_specifier(asset))
    |> OXC.codegen!()
    |> then(&["\n", String.trim(&1)])
  end

  defp style_import(path, module) do
    specifier = Volt.Plugin.EmbeddedModule.specifier(path, module)

    "import \"__specifier__\";"
    |> OXC.parse!("vue-style-import-template.ts")
    |> Volt.JS.AST.replace_literal("__specifier__", specifier)
    |> OXC.codegen!()
    |> then(&["\n", String.trim(&1)])
  end

  defp imports(source, assets) do
    script_imports = source |> scripts() |> Enum.flat_map(&script_imports/1)
    script_imports ++ Enum.map(assets, &asset_specifier/1)
  end

  defp asset_specifier(asset), do: asset.url |> String.split("#", parts: 2) |> hd()

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
