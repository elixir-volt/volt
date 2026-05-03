# Plugins

## Built-in Plugins

Volt includes built-in support for Vue, Svelte, and React. These are activated automatically when you import `.vue` or `.svelte` files, or configure `import_source: "react"`.

## Using Plugins

Add plugins to your Volt config:

```elixir
config :volt, plugins: [MyApp.MarkdownPlugin]
```

## Writing Plugins

Extend the build pipeline with the `Volt.Plugin` behaviour:

```elixir
defmodule MyApp.MarkdownPlugin do
  @behaviour Volt.Plugin

  @impl true
  def name, do: "markdown"

  @impl true
  def resolve(spec, _importer) do
    if String.ends_with?(spec, ".md"), do: {:ok, spec}
  end

  @impl true
  def load(path) do
    if String.ends_with?(path, ".md") do
      html = path |> File.read!() |> Earmark.as_html!()
      {:ok, "export default #{Jason.encode!(html)};\n"}
    end
  end

  def resolve(_, _), do: nil
  def load(_), do: nil
end
```

## Hooks

All hooks are optional. Return `nil` to pass to the next plugin.

| Hook | Purpose |
| --- | --- |
| `name/0` | Plugin identifier (required) |
| `extensions/1` | File extensions this plugin handles |
| `resolve/2` | Resolve import specifiers to file paths |
| `load/1` | Load file content for a resolved path |
| `compile/3` | Compile source into browser-ready JS + optional CSS |
| `extract_imports/3` | Extract import specifiers from source |
| `transform/2` | Transform compiled JS before serving |
| `define/1` | Compile-time variable replacements |
| `prebundle_alias/1` | Canonical prebundle specifier for an import |
| `prebundle_entry/1` | Generated prebundle entry module |
| `render_chunk/2` | Transform final output chunks |

## JavaScript Runtimes

Plugins can run JavaScript build tools through `Volt.JS.Runtime`, which installs npm packages into Volt's cache and executes them in QuickBEAM without requiring Node.js:

```elixir
runtime = Volt.JS.Runtime.ensure!(
  name: MyPlugin.Runtime,
  packages: %{"some-tool" => "^1.0.0"},
  entry: {:volt_asset, "my-runtime.ts"},
  bundle: true
)

{:ok, result} = Volt.JS.Runtime.call(runtime, "transform", [source])
```
