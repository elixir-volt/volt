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

## Plugin ordering

Plugins run in Vite-style phases. By default, plugins run in the order they are configured. Return `:pre` or `:post` from `enforce/0` to run before or after normal plugins:

```elixir
defmodule MyApp.PrePlugin do
  @behaviour Volt.Plugin

  def name, do: "my-pre-plugin"
  def enforce, do: :pre
end
```

The ordering applies consistently to resolve, load, compile, transform, define, prebundle, and render hooks.

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

```javascript
import readme from './README.md'
document.getElementById('content').innerHTML = readme
```

### Example: Virtual modules and virtual entries

Plugins can resolve generated module ids and load their source without a file on disk. This is useful for framework and site-generator integrations that generate route manifests, island registries, or client boot entries.

```elixir
defmodule MySite.VoltPlugin do
  @behaviour Volt.Plugin

  @impl true
  def name, do: "my-site"

  @impl true
  def resolve("virtual:my-site/client", _importer), do: {:ok, "virtual:my-site/client"}
  def resolve("virtual:my-site/routes", _importer), do: {:ok, "virtual:my-site/routes"}
  def resolve(_specifier, _importer), do: nil

  @impl true
  def load("virtual:my-site/client") do
    {:ok, "import routes from 'virtual:my-site/routes'; console.log(routes);\n"}
  end

  def load("virtual:my-site/routes") do
    {:ok, "export default [{ path: '/', component: 'Home' }];\n"}
  end

  def load(_id), do: nil
end
```

Virtual modules can be imported by normal source files. They can also be production build entries when the same plugin is passed to `Volt.Builder.build/1`:

```elixir
Volt.Builder.build(
  entry: "virtual:my-site/client",
  outdir: "priv/static/assets",
  plugins: [MySite.VoltPlugin]
)
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

```javascript
console.log(`Build ${__BUILD_HASH__} at ${__BUILD_TIME__}`)
```

### CSS compilation

A plugin's `compile/3` callback can return both a JavaScript module in `:code` and extracted CSS in `:css`. Volt injects that CSS in development, collects it into the production CSS file, and runs parser-backed asset URL rewriting on the final output.

Sass and SCSS do not require a plugin: Volt compiles `.sass`, `.scss`, `.module.sass`, and `.module.scss` files directly through its native Rust pipeline. See [Features](features.md#sass-and-scss).

### Embedded modules for single-file formats

Plugins that own single-file formats can expose child script/style modules with `embedded_modules/3`. Volt addresses them as query modules derived from the parent file, for example `Card.box?volt-embedded=1&type=style&index=0`, so dev serving, HMR, production collection, type-aware checks, and sourcemaps keep the real source file as the anchor.

```elixir
defmodule MyApp.BoxPlugin do
  @behaviour Volt.Plugin

  alias Volt.Plugin.EmbeddedModule

  def name, do: "box"

  def extensions(kind) when kind in [:compile, :resolve, :watch, :scan], do: [".box"]
  def extensions(_kind), do: []

  def compile(path, source, _opts) do
    if Path.extname(path) == ".box" do
      modules = source |> blocks() |> EmbeddedModule.normalize_all()

      imports =
        modules
        |> Enum.map(&EmbeddedModule.specifier(path, &1))
        |> Enum.map_join("\n", &"import #{inspect(&1)};")

      {:ok, %Volt.Pipeline.Result{code: imports <> "\nexport default {};\n"}}
    end
  end

  def embedded_modules(path, source, _opts) do
    if Path.extname(path) == ".box", do: blocks(source)
  end

  defp blocks(source) do
    [
      %EmbeddedModule{type: :style, extension: ".css", source: extract_style(source)},
      %EmbeddedModule{type: :script, extension: ".ts", source: extract_script(source)}
    ]
  end
end
```

The parent compile output imports `EmbeddedModule.specifier/2`; Volt resolves those imports back to the parent file's embedded modules and compiles each child according to its extension/content type.

### Example: Custom file compilation with OXC templates

Use `compile/3` to handle a custom file format. OXC templates let you generate JavaScript from real JavaScript syntax instead of string concatenation:

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
  def compile(path, source, _opts) do
    if Path.extname(path) == ".csv" do
      rows =
        source
        |> String.split("\n", trim: true)
        |> Enum.map(&String.split(&1, ","))

      js =
        "export default $rows;"
        |> OXC.parse!("csv-template.js")
        |> OXC.bind(rows: {:literal, rows})
        |> OXC.codegen!()

      {:ok, %{code: js, sourcemap: nil, css: nil, hashes: nil}}
    end
  end
end
```

```javascript
import data from './prices.csv'
// data = [["name", "price"], ["Widget", "9.99"], ...]
```

For larger generated modules, keep the template in `priv` so editors and formatters understand it:

```javascript
// priv/templates/api-client.js
export default {
  name: $name,
  endpoint: $endpoint,
  columns: $columns,
}
```

```elixir
@templates {:my_app, "templates"}

js =
  Volt.Priv.js!(@templates, "api-client.js",
    name: "prices",
    endpoint: "/api/prices",
    columns: ["name", "price"]
  )
```

`Volt.Priv.js!/3` reads from the OTP application's `priv` directory, binds
`$placeholder` JavaScript literals with OXC, and emits browser JavaScript.

Use the `:splices` option when a placeholder represents statements, object properties,
or array elements rather than a literal:

```javascript
// priv/templates/plugin-entry.ts
$imports

export function install() {
  $setup
}
```

```elixir
Volt.Priv.render!(@templates, "plugin-entry.ts", [],
  splices: [
    imports: [~s|import "./runtime.js";|, ~s|import "./styles.css";|],
    setup: "registerPlugin(); startRuntime();"
  ]
)
```

Splices use `OXC.splice/3`, so replacements are parsed as JavaScript syntax rather
than inserted with textual replacement. A replacement can be an AST node, source or
iodata containing multiple nodes, or a list of those values. `render!/4` preserves
TypeScript for the subsequent Volt build; use `js!/4` when the caller needs compiled
browser JavaScript immediately.

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
| `embedded_modules/3` | Expose JavaScript-like modules embedded in a custom source format |
| `transform/2` | Transform compiled JS before serving or bundling |
| `define/1` | Compile-time variable replacements |
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

`extract_imports/3` returns structured import metadata when a plugin owns a source format whose dependencies are not visible to Volt's normal JavaScript parser:

```elixir
alias Volt.JS.ImportExtractor.Result

def extract_imports(".widget" <> _ = _path, _source, _opts) do
  {:ok, %Result{imports: [{:static, "./runtime"}], workers: []}}
end

def extract_imports(_path, _source, _opts), do: nil
```

`embedded_modules/3` exposes JavaScript-like modules inside custom file formats. Volt uses this for type-aware linting so tools such as `tsgolint` can analyze embedded scripts without receiving the original component file directly:

```elixir
def embedded_modules(path, source, _opts) do
  if Path.extname(path) == ".widget" do
    [{".ts", extract_script(source)}]
  end
end
```

The first tuple element is the virtual file extension (`".js"`, `".ts"`, or `".tsx"`), and the second is the embedded source. Diagnostics are reported against the original file.

### Advanced framework runtime integration

Framework plugins can also coordinate Volt's dev dependency prebundling. These hooks are Volt-specific; Vite framework plugins achieve similar results through dependency optimization, resolution, and virtual modules rather than direct hooks with these names.

| Hook | Purpose |
| --- | --- |
| `prebundle_alias/1` | Normalize related package entrypoints to one dev prebundle |
| `prebundle_entry/1` | Generate a source or proxy entry for that dev prebundle |

Use `prebundle_alias/1` when several package entrypoints should share one generated dev vendor module:

```elixir
def prebundle_alias("my-framework/runtime"), do: "my-framework"
def prebundle_alias("my-framework/jsx-runtime"), do: "my-framework"
def prebundle_alias(_specifier), do: nil
```

Use `prebundle_entry/1` when the canonical specifier needs a generated proxy module:

```elixir
alias Volt.JS.PrebundleEntry.{Export, Import}

def prebundle_entry("my-framework") do
  {:proxy, "my-framework.js",
   imports: [Import.default("Framework", from: "my-framework")],
   exports: [
     Export.default("Framework"),
     Export.members([
       {"createApp", "Framework.createApp"},
       {"hydrate", "Framework.hydrate"}
     ]),
     Export.all_from("my-framework/runtime")
   ]}
end

def prebundle_entry(_specifier), do: nil
```

Return `nil` from either hook to let Volt keep the original specifier or generate a normal package prebundle.

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

Plugins can run JavaScript build tools through `Volt.JS.Runtime`, which installs npm packages into Volt's cache and executes them in QuickBEAM without requiring Node.js in the host application. This is useful for tools that do not have a native Elixir or Rust binding:

```elixir
defmodule MyApp.MarkdownPlugin do
  @behaviour Volt.Plugin

  @runtime_name __MODULE__.Runtime
  @runtime_packages %{"marked" => "^16.0.0"}
  @entry """
  import { marked } from "marked";
  export function renderMarkdown(source) { return marked.parse(source); }
  """

  @impl true
  def name, do: "markdown"

  @impl true
  def extensions(:compile), do: [".md"]
  def extensions(:resolve), do: [".md"]
  def extensions(_), do: []

  @impl true
  def compile(path, source, _opts) do
    if Path.extname(path) == ".md" do
      runtime =
        Volt.JS.Runtime.ensure!(
          name: @runtime_name,
          packages: @runtime_packages,
          entry: {:source, @entry, "markdown-runtime.ts"},
          bundle: true
        )

      case Volt.JS.Runtime.call(runtime, "renderMarkdown", [source]) do
        {:ok, html} -> {:ok, %{code: "export default #{Jason.encode!(html)};\n"}}
        {:error, _} = error -> error
      end
    end
  end
end
```

The runtime automatically installs npm packages on first use and caches the bundled entry script. Subsequent calls reuse the running QuickBEAM instance.

Frameworks that bundle package-owned browser modules without executing them in
QuickBEAM can install those dependencies directly and scope them to the framework's
source root:

```elixir
packages =
  Volt.NPM.install!(
    %{"framework-runtime" => "1.2.3"},
    lockfile: Application.app_dir(:my_framework, "priv/npm.lock")
  )

Volt.Builder.build(
  entry: "assets/app.ts",
  node_modules: "assets/node_modules",
  package_scopes: [
    {Application.app_dir(:my_framework, "priv/ts"), packages.node_modules}
  ]
)
```

A package-owned npm_ex lockfile pins the complete transitive graph and lets fresh
cache installations skip registry resolution. Volt validates its version, security
policy, direct versions, integrity metadata, and required dependency closure before
linking packages.

An import originating below the scoped source root checks the framework package
directory first. Imports from application modules continue to resolve from the
application's `node_modules`, so package names and versions cannot shadow one another.
