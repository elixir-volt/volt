defmodule Volt.Plugin.Svelte do
  @moduledoc """
  Built-in Svelte support for Volt.
  """

  @behaviour Volt.Plugin

  @runtime_packages %{"svelte" => "^5.0.0"}
  @runtime_name __MODULE__.Runtime
  @resolve_extensions Volt.JS.Extensions.node_resolvable()

  @impl true
  def name, do: "svelte"

  @impl true
  def extensions(kind) when kind in [:compile, :resolve, :watch, :scan], do: [".svelte"]
  def extensions(_), do: []

  @impl true
  def prebundle_alias("svelte/internal/client"), do: "svelte"
  def prebundle_alias(_specifier), do: nil

  @impl true
  def prebundle_entry("svelte") do
    {:proxy, "svelte.js",
     exports: [
       Volt.JS.PrebundleEntry.Export.all_from("svelte"),
       Volt.JS.PrebundleEntry.Export.all_from("svelte/internal/client")
     ]}
  end

  def prebundle_entry(_specifier), do: nil

  @impl true
  def resolve("svelte", importer), do: resolve_svelte("svelte", importer)
  def resolve("svelte/" <> _ = specifier, importer), do: resolve_svelte(specifier, importer)
  def resolve(_, _), do: nil

  defp resolve_svelte(specifier, _importer) do
    install = Volt.JS.Runtime.Installer.install!(@runtime_packages)

    case NPM.Resolution.PackageResolver.resolve(specifier, install.install_dir,
           extensions: @resolve_extensions,
           conditions: Volt.JS.Resolution.browser_conditions()
         ) do
      {:ok, path} -> {:ok, path}
      {:builtin, _} -> :skip
      :error -> nil
    end
  end

  @impl true
  def compile(path, source, opts), do: compile(path, source, opts, [])

  def compile(path, source, opts, plugin_opts) do
    if Path.extname(path) == ".svelte" do
      do_compile(path, source, opts, plugin_opts)
    end
  end

  @impl true
  def extract_imports(path, source, opts), do: extract_imports(path, source, opts, [])

  def extract_imports(path, source, opts, _plugin_opts) do
    if Path.extname(path) == ".svelte" do
      do_extract_imports(path, source, opts)
    end
  end

  @impl true
  def embedded_modules(path, source, opts), do: embedded_modules(path, source, opts, [])

  def embedded_modules(path, source, _opts, _plugin_opts) do
    if Path.extname(path) == ".svelte" do
      script_blocks(source)
    end
  end

  def runtime_packages, do: @runtime_packages

  defp do_compile(path, source, opts, plugin_opts) do
    runtime =
      Volt.JS.Runtime.ensure!(
        name: @runtime_name,
        packages: @runtime_packages,
        apis: [:browser, :node],
        entry: {:volt_asset, "frameworks/svelte.ts"},
        bundle: true,
        max_stack_size: 16 * 1024 * 1024
      )

    compile_options =
      path
      |> Volt.Plugin.Svelte.CompilerOptions.new(opts, plugin_opts)
      |> Jason.encode!()

    case Volt.JS.Runtime.call(runtime, "compileSvelte", [source, compile_options]) do
      {:ok, %{"js" => js, "css" => css, "jsMap" => js_map} = result} ->
        {:ok,
         %Volt.Pipeline.Result{
           code: js,
           sourcemap: encode_sourcemap(js_map),
           css: empty_to_nil(css),
           hashes: %Volt.Pipeline.Result.Hashes{
             template: nil,
             style: hash(css),
             script: hash(source)
           },
           warnings: Map.get(result, "warnings", [])
         }}

      {:ok, other} ->
        {:error, {:unexpected_svelte_result, other}}

      {:error, _} = error ->
        error
    end
  end

  defp do_extract_imports(path, source, opts) do
    scripts = script_blocks(source)
    loaders = Keyword.get(opts, :loaders, %{})

    scripts
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, %Volt.JS.ImportExtractor.Result{}}, fn {{extension, script}, index},
                                                                      {:ok, acc} ->
      filename =
        path
        |> Path.basename()
        |> Volt.JS.Extensions.apply_loader(loaders)
        |> Kernel.<>(".script#{index}#{extension}")

      case OXC.select(script, filename, :import_sources) do
        {:ok, imports} ->
          typed = Enum.map(imports, &{&1.type, &1.specifier})
          {:cont, {:ok, %{acc | imports: [typed | acc.imports]}}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, result} ->
        {:ok, %{result | imports: result.imports |> Enum.reverse() |> List.flatten()}}

      error ->
        error
    end
  end

  defp script_blocks(source) do
    case Floki.parse_fragment(source) do
      {:ok, document} ->
        document
        |> Floki.find("script")
        |> Enum.map(fn node -> {script_extension(script_lang(node)), node_text(node)} end)

      {:error, _reason} ->
        []
    end
  end

  defp script_lang({_tag, attrs, _children}) do
    attrs
    |> Enum.find_value(fn
      {"lang", lang} -> lang
      _attr -> nil
    end)
  end

  defp script_extension("ts"), do: ".ts"
  defp script_extension("tsx"), do: ".tsx"
  defp script_extension(_lang), do: ".js"

  defp node_text({_tag, _attrs, children}), do: Enum.map_join(children, &node_text/1)
  defp node_text(text) when is_binary(text), do: text
  defp node_text(_node), do: ""

  defp encode_sourcemap(nil), do: nil
  defp encode_sourcemap(map), do: Jason.encode!(map)

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp hash(value), do: Volt.Plugin.Helpers.cache_hash(value)
end
