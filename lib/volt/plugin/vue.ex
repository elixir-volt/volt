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
    if Path.extname(path) == ".vue" do
      sfc_opts = [
        filename: Path.basename(path),
        vapor: Keyword.get(opts, :vapor, false),
        strip_types: true,
        custom_renderer: Keyword.get(opts, :custom_renderer, false)
      ]

      case Vize.compile_sfc(source, sfc_opts) do
        {:ok, result} ->
          {:ok,
           %{
             code: result.code,
             sourcemap: nil,
             css: result.css,
             hashes: %{
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
      {:ok, specs} = Volt.JS.VueImports.extract(source)
      {:ok, %{imports: Enum.map(specs, &{:static, &1}), workers: []}}
    end
  end
end
