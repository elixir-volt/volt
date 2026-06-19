defmodule Volt.Plugin.Solid do
  @moduledoc """
  Solid JSX/TSX support for Volt.

  Solid JSX requires the Solid compiler rather than a generic JSX runtime
  transform. This plugin runs `babel-preset-solid` through Volt's JavaScript
  runtime and leaves normal module resolution to Volt. Add `Volt.Plugin.Solid`
  to `config :volt, :plugins` when using Solid TSX, since `.jsx` and `.tsx`
  files are also used by React and generic JSX builds.
  """

  @behaviour Volt.Plugin

  @runtime_packages %{
    "@babel/standalone" => "^7.0.0",
    "babel-preset-solid" => "^1.9.0"
  }

  @runtime_name __MODULE__.Runtime
  @jsx_exts ~w(.jsx .tsx)
  @impl true
  def name, do: "solid"

  @impl true
  def compile(path, source, opts), do: compile(path, source, opts, [])

  def compile(path, source, opts, plugin_opts) do
    filename = compile_filename(path, opts)

    if solid_file?(filename) do
      do_compile(source, filename, opts, plugin_opts)
    end
  end

  @impl true
  def extract_imports(path, source, opts), do: extract_imports(path, source, opts, [])

  def extract_imports(path, source, opts, _plugin_opts) do
    filename = compile_filename(path, opts)

    if solid_file?(filename) do
      with {:ok, %{imports: imports} = result} <- extract_typed_imports(source, filename) do
        {:ok, %{result | imports: add_compiler_imports(imports)}}
      end
    end
  end

  @impl true
  def prebundle_alias("solid-js/web"), do: "solid-js"
  def prebundle_alias(_specifier), do: nil

  @impl true
  def prebundle_entry("solid-js") do
    {:proxy, "solid-js.js",
     exports: [
       Volt.JS.PrebundleEntry.Export.all_from("solid-js"),
       Volt.JS.PrebundleEntry.Export.all_from("solid-js/web")
     ]}
  end

  def prebundle_entry(_specifier), do: nil

  def runtime_packages, do: @runtime_packages

  defp do_compile(source, filename, opts, plugin_opts) do
    runtime =
      Volt.JS.Runtime.ensure!(
        name: @runtime_name,
        packages: @runtime_packages,
        apis: [:browser, :node],
        entry: {:volt_asset, "frameworks/solid.ts"},
        bundle: true,
        max_stack_size: 32 * 1024 * 1024
      )

    compile_options =
      filename
      |> Volt.Plugin.Solid.CompilerOptions.new(opts, plugin_opts)
      |> Jason.encode!()

    case Volt.JS.Runtime.call(runtime, "compileSolid", [source, compile_options]) do
      {:ok, %{"code" => code, "map" => map}} ->
        with {:ok, code, downlevelled?} <- maybe_downlevel(code, filename, opts) do
          {:ok,
           %Volt.Pipeline.Result{
             code: code,
             sourcemap: encode_sourcemap(map, downlevelled?),
             css: nil,
             hashes: %Volt.Pipeline.Result.Hashes{template: nil, style: nil, script: hash(source)}
           }}
        end

      {:ok, other} ->
        {:error, {:unexpected_solid_result, other}}

      {:error, _} = error ->
        error
    end
  end

  defp maybe_downlevel(code, filename, opts) do
    case Keyword.get(opts, :target) do
      nil ->
        {:ok, code, false}

      "" ->
        {:ok, code, false}

      target ->
        case OXC.transform(code, js_filename(filename),
               target: to_string(target),
               sourcemap: false
             ) do
          {:ok, transformed} when is_binary(transformed) ->
            {:ok, transformed, transformed != code}

          {:ok, %{code: transformed}} ->
            {:ok, transformed, transformed != code}

          {:error, _} = error ->
            error
        end
    end
  end

  defp js_filename(filename), do: Path.rootname(filename) <> ".js"

  defp compile_filename(path, opts) do
    path
    |> Path.basename()
    |> Volt.JS.Extensions.apply_loader(Keyword.get(opts, :loaders, %{}))
  end

  defp solid_file?(filename), do: Path.extname(filename) in @jsx_exts

  defp add_compiler_imports(imports) do
    imports
    |> Enum.concat([{:static, "solid-js/web"}])
    |> Enum.uniq()
  end

  defp extract_typed_imports(source, filename) do
    Volt.JS.ImportExtractor.extract_typed(source, filename, ignore_type_only: true)
  end

  defp encode_sourcemap(_map, true), do: nil
  defp encode_sourcemap(nil, false), do: nil
  defp encode_sourcemap(map, false) when is_map(map), do: Jason.encode!(map)
  defp encode_sourcemap(value, false) when is_binary(value), do: value

  defp hash(value), do: Volt.Plugin.Helpers.cache_hash(value)
end
