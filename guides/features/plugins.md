# Plugins

## Built-in Plugins

Volt includes built-in support for Vue, Svelte, and React. These are activated automatically when you import `.vue` or `.svelte` files, or configure `import_source: "react"`.

## Using Plugins

Add plugins to your Volt config:

```elixir
config :volt, plugins: [MyApp.MarkdownPlugin]
```

Plugins can also accept options as `{module, opts}` tuples:

```elixir
config :volt, plugins: [{MyApp.SassPlugin, output_style: :compressed}]
```

## Writing Plugins

Implement the `Volt.Plugin` behaviour. All callbacks except `name/0` are optional — implement only the hooks you need.

### Example: Markdown imports

Load `.md` files as HTML string modules:

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

```typescript
import readme from './README.md'
document.getElementById('content').innerHTML = readme
```

### Example: Banner injection

Use `render_chunk/2` to prepend a license banner to production output:

```elixir
defmodule MyApp.BannerPlugin do
  @behaviour Volt.Plugin

  @banner "/* © 2026 MyApp — MIT License */\n"

  @impl true
  def name, do: "banner"

  @impl true
  def render_chunk(code, %{type: :entry}), do: {:ok, @banner <> code}
  def render_chunk(_code, _chunk_info), do: nil
end
```

### Example: Compile-time constants

Use `define/1` to inject build-time values:

```elixir
defmodule MyApp.BuildInfo do
  @behaviour Volt.Plugin

  @impl true
  def name, do: "build-info"

  @impl true
  def define(_mode) do
    {hash, 0} = System.cmd("git", ["rev-parse", "--short", "HEAD"])

    %{
      "__BUILD_HASH__" => Jason.encode!(String.trim(hash)),
      "__BUILD_TIME__" => Jason.encode!(DateTime.utc_now() |> to_string())
    }
  end
end
```

```typescript
console.log(`Build ${__BUILD_HASH__} at ${__BUILD_TIME__}`)
```

### Example: Custom file compilation with OXC

Use `compile/3` to handle a custom file format, transforming output with OXC:

```elixir
defmodule MyApp.CSVPlugin do
  @behaviour Volt.Plugin

  @impl true
  def name, do: "csv"

  @impl true
  def extensions(:compile), do: [".csv"]
  def extensions(:resolve), do: [".csv"]
  def extensions(_), do: []

  @impl true
  def resolve(spec, _importer) do
    if String.ends_with?(spec, ".csv"), do: {:ok, spec}
  end

  def resolve(_, _), do: nil

  @impl true
  def compile(path, source, opts) do
    if Path.extname(path) == ".csv" do
      rows =
        source
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ","))

      js = "export default #{Jason.encode!(rows)};\n"

      {:ok, %{code: js, sourcemap: nil, css: nil, hashes: nil}}
    end
  end
end
```

```typescript
import data from './prices.csv'
// data = [["name", "price"], ["Widget", "9.99"], ...]
```

### Example: AST transform with OXC

Use `transform/2` to modify compiled JavaScript. OXC provides `parse/2`, `postwalk/3`, and `patch_string/2` for AST-based transforms:

```elixir
defmodule MyApp.StripConsolePlugin do
  @behaviour Volt.Plugin

  @impl true
  def name, do: "strip-console"

  @impl true
  def transform(code, _path) do
    case OXC.parse(code, "module.js") do
      {:ok, ast} ->
        patches =
          collect_console_calls(ast)
          |> Enum.map(fn %{start: s, end: e} ->
            %{start: s, end: e, change: "void 0"}
          end)

        if patches == [] do
          nil
        else
          {:ok, OXC.patch_string(code, patches)}
        end

      {:error, _} ->
        nil
    end
  end

  defp collect_console_calls(ast) do
    {_ast, calls} =
      OXC.postwalk(ast, [], fn
        %{
          type: :call_expression,
          callee: %{
            type: :member_expression,
            object: %{type: :identifier, name: "console"}
          }
        } = node, acc ->
          {node, [node | acc]}

        node, acc ->
          {node, acc}
      end)

    calls
  end
end
```

## Hooks

All hooks are optional. Return `nil` to pass to the next plugin.

| Hook | Purpose |
| --- | --- |
| `name/0` | Plugin identifier (required) |
| `extensions/1` | File extensions for `:compile`, `:resolve`, `:watch`, or `:scan` |
| `resolve/2` | Resolve import specifiers to file paths |
| `load/1` | Load file content for a resolved path |
| `compile/3` | Compile source into browser-ready JS + optional CSS |
| `extract_imports/3` | Extract import specifiers from source |
| `transform/2` | Transform compiled JS before serving or bundling |
| `define/1` | Compile-time variable replacements |
| `prebundle_alias/1` | Canonical prebundle specifier for an import |
| `prebundle_entry/1` | Generated prebundle entry module |
| `render_chunk/2` | Transform final output chunks |

### Hook execution order

During compilation, hooks run in this order:

1. **`resolve`** — map import specifier to a file path
2. **`load`** — read file content (override `File.read`)
3. **`compile`** — transform source into JS + CSS
4. **`extract_imports`** — find imports for dependency walking
5. **`transform`** — post-process compiled JS
6. **`render_chunk`** — modify final bundled output

`define/1` runs once at build start. `extensions/1` is checked throughout to determine which files a plugin handles.

### Plugin options

When configured as a `{module, opts}` tuple, the opts are passed as an extra argument to callbacks that support it. Define a callback with one additional arity to receive them:

```elixir
defmodule MyApp.SassPlugin do
  @behaviour Volt.Plugin

  @impl true
  def name, do: "sass"

  # 3-arg version (standard)
  def compile(path, source, opts), do: compile(path, source, opts, [])

  # 4-arg version receives plugin opts
  def compile(path, source, opts, plugin_opts) do
    style = Keyword.get(plugin_opts, :output_style, :expanded)
    # ...
  end
end
```

## JavaScript Runtimes

Plugins can run JavaScript build tools through `Volt.JS.Runtime`, which installs npm packages into Volt's cache and executes them in QuickBEAM without requiring Node.js in the host application:

```elixir
defmodule MyApp.SassPlugin do
  @behaviour Volt.Plugin

  @runtime_name __MODULE__.Runtime
  @runtime_packages %{"sass" => "^1.80.0"}

  @impl true
  def name, do: "sass"

  @impl true
  def extensions(:compile), do: [".scss"]
  def extensions(:resolve), do: [".scss"]
  def extensions(_), do: []

  @impl true
  def compile(path, source, _opts) do
    if Path.extname(path) == ".scss" do
      runtime =
        Volt.JS.Runtime.ensure!(
          name: @runtime_name,
          packages: @runtime_packages,
          entry: {:volt_asset, "sass-runtime.ts"},
          bundle: true
        )

      case Volt.JS.Runtime.call(runtime, "compileSass", [source, path]) do
        {:ok, %{"css" => css}} ->
          js = "var s = document.createElement('style'); s.textContent = #{Jason.encode!(css)}; document.head.appendChild(s);\n"
          {:ok, %{code: js, sourcemap: nil, css: css, hashes: nil}}

        {:error, _} = error ->
          error
      end
    end
  end
end
```

The runtime automatically installs npm packages on first use and caches the bundled entry script. Subsequent calls reuse the running QuickBEAM instance.
