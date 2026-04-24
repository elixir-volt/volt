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
      vapor = Keyword.get(opts, :vapor, false)

      case Vize.compile_sfc(source, filename: Path.basename(path), vapor: vapor) do
        {:ok, result} ->
          code = strip_typescript(result.code, path, opts)

          {:ok,
           %{
             code: code,
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

  defp strip_typescript(code, path, opts) do
    ts_name = Path.rootname(Path.basename(path)) <> ".ts"

    transform_opts =
      [sourcemap: false]
      |> maybe_put(:target, Keyword.get(opts, :target))

    case OXC.transform(code, ts_name, transform_opts) do
      {:ok, %{code: stripped}} -> stripped
      {:ok, stripped} when is_binary(stripped) -> stripped
      {:error, _} -> code
    end
  end

  defp maybe_put(opts, _key, nil), do: opts

  defp maybe_put(opts, key, value) when is_atom(value),
    do: Keyword.put(opts, key, Atom.to_string(value))

  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
