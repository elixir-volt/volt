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
  def resolve("svelte" <> _ = specifier, _importer) do
    install = Volt.JS.Runtime.Installer.install!(@runtime_packages)

    case Volt.JS.PackageResolver.resolve(specifier, install.install_dir,
           extensions: @resolve_extensions
         ) do
      {:ok, path} -> {:ok, path}
      {:builtin, _} -> :skip
      :error -> nil
    end
  end

  def resolve(_, _), do: nil

  @impl true
  def compile(path, source, opts) do
    if Path.extname(path) == ".svelte" do
      do_compile(path, source, opts)
    end
  end

  @impl true
  def extract_imports(path, source, opts) do
    if Path.extname(path) == ".svelte" do
      do_extract_imports(path, source, opts)
    end
  end

  def runtime_packages, do: @runtime_packages

  defp do_compile(path, source, opts) do
    runtime =
      Volt.JS.Runtime.ensure!(
        name: @runtime_name,
        packages: @runtime_packages,
        apis: [:browser, :node],
        entry: {:volt_asset, "svelte-runtime.ts"},
        bundle: true
      )

    compile_options = %{
      "filename" => path,
      "generate" => compile_target(opts),
      "dev" => Keyword.get(opts, :dev, false),
      "css" => Keyword.get(opts, :css, "external")
    }

    case Volt.JS.Runtime.call(runtime, "compileSvelte", [source, compile_options]) do
      {:ok, %{"js" => js, "css" => css, "jsMap" => js_map}} ->
        {:ok,
         %{
           code: js,
           sourcemap: encode_sourcemap(js_map),
           css: empty_to_nil(css),
           hashes: %{template: nil, style: hash(css), script: hash(source)}
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
    |> Enum.reduce_while({:ok, %{imports: [], workers: []}}, fn {script, index}, {:ok, acc} ->
      filename =
        path
        |> Path.basename()
        |> Volt.JS.Extensions.apply_loader(loaders)
        |> Kernel.<>(".script#{index}.ts")

      case OXC.collect_imports(script, filename) do
        {:ok, imports} ->
          typed = Enum.map(imports, &{&1.type, &1.specifier})
          {:cont, {:ok, %{acc | imports: acc.imports ++ typed}}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end

  defp script_blocks(source) do
    case Floki.parse_fragment(source) do
      {:ok, document} ->
        document
        |> Floki.find("script")
        |> Enum.map(&node_text/1)

      {:error, _reason} ->
        []
    end
  end

  defp node_text({_tag, _attrs, children}), do: Enum.map_join(children, &node_text/1)
  defp node_text(text) when is_binary(text), do: text
  defp node_text(_node), do: ""

  defp compile_target(opts) do
    case Keyword.get(opts, :svelte_generate, :client) do
      :client -> "client"
      :server -> "server"
      value when is_binary(value) -> value
    end
  end

  defp encode_sourcemap(nil), do: nil
  defp encode_sourcemap(map), do: Jason.encode!(map)

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp hash(nil), do: nil
  defp hash(""), do: nil
  defp hash(value), do: :erlang.phash2(value) |> Integer.to_string(16)
end
