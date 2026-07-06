# Volt ⚡

[![Hex.pm](https://img.shields.io/hexpm/v/volt.svg)](https://hex.pm/packages/volt) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/volt)

Vite-level frontend tooling that runs inside the BEAM. One dep replaces esbuild, the Tailwind CLI, and Node.js with Rust NIFs powered by [OXC](https://oxc.rs), [LightningCSS](https://lightningcss.dev), and [QuickBEAM](https://github.com/elixir-volt/quickbeam) for embedded JavaScript runtimes.

```bash
mix igniter.install volt
mix phx.server
```

The installer configures everything. No binaries to download, no extra processes to manage.

## Why Volt

Phoenix ships with esbuild and a Tailwind CLI as separate binaries downloaded at compile time. They can't coordinate HMR or share work, and anything beyond vanilla JS requires Node.js.

Volt replaces both with a single Elixir dep. `mix phx.server` starts the frontend toolchain automatically, rebuilding Tailwind in ~40ms on template changes and hot-swapping JS modules via HMR. Compilation errors show as a browser overlay. Production builds finish in under 100ms.

You also get features you'd expect from Vite: code splitting, CSS Modules, JSON imports, asset query modes, web workers, HTML entry points, `import.meta.glob()`, dynamic import variables, `.env` variables, static asset imports, import aliases, and `import.meta.hot` with state preservation.

The pieces integrate because they run in one toolchain: template edits can trigger incremental Tailwind rebuilds, browser console output can flow back to your Elixir terminal, and project-specific JS/TS lint rules can be written as Elixir modules. See the [Features guide](https://hexdocs.pm/volt/features.html) for the full list.

## Installation

```bash
mix igniter.install volt
```

Or add the dep manually:

```elixir
def deps do
  [{:volt, "~> 0.14"}]
end
```

See the [Getting Started guide](https://hexdocs.pm/volt/getting-started.html) for manual configuration.

## Configuration

Standard `config/*.exs`. No `vite.config.js`, no `tailwind.config.js`:

```elixir
config :volt,
  entry: ["assets/js/app.ts", "assets/js/admin.ts"],
  target: :es2020,
  import_source: "react",
  aliases: %{
    "@" => "assets/src",
    "@components" => "assets/src/components"
  },
  external: ~w(phoenix phoenix_html phoenix_live_view),
  chunks: %{
    "vendor" => ["react", "react-dom"],
    "ui" => ["assets/src/components"]
  },
  env_prefix: ["VOLT_", "PUBLIC_"],
  asset_url_prefix: "/assets",
  public_dir: "public",
  sourcemap: :hidden,
  tailwind: [
    css: "assets/css/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{js,ts,jsx,tsx,vue,svelte}"}
    ]
  ],
  plugins: [MyApp.MarkdownPlugin]

config :volt, :server,
  prefix: "/assets",
  watch_dirs: ["lib/"]
```

`Volt.static_path/2` resolves Volt-managed assets to source files in dev and content-hashed paths in production:

```heex
<link phx-track-static rel="stylesheet" href={Volt.static_path(@endpoint, "/assets/css/app.css")} />
<script defer phx-track-static type="module" src={Volt.static_path(@endpoint, "/assets/js/app.js")}></script>
<img src={Volt.static_path(@endpoint, "/assets/images/logo.svg")} />
```

## Production builds

```
$ mix volt.build

Building Tailwind CSS...
  app-1a2b3c4d.css  23.9 KB
Built Tailwind in 43ms
Building "assets/js/app.ts"...
  app-5e6f7a8b.js  128.4 KB  (gzip: 38.2 KB)
  manifest.json  2 entries
Built in 15ms
```

Tree-shaking, minification, code splitting, configurable env prefixes and asset URL prefixes, source maps, content-hashed JavaScript/CSS/assets, and manifest output. `Volt.Preload.tags/2` can generate modulepreload tags from the manifest, and the build is ready for `mix phx.digest`.

## Framework support

Vue SFCs with scoped CSS, React JSX with the automatic runtime, Svelte 5 with runes, and Solid JSX all compile without Node.js installed. Plain TypeScript with LiveView hooks works too.

See the [examples](https://github.com/elixir-volt/volt/tree/master/examples) for complete Phoenix projects with each framework.

## Developer tools

JS/TS formatting, linting, and testing run inside the BEAM. `mix format` handles Elixir and JavaScript together:

```elixir
# .formatter.exs
[plugins: [Volt.Formatter], inputs: ["assets/**/*.{js,ts,jsx,tsx}"]]
```

```bash
mix format           # Elixir + JS/TS
mix volt.lint        # 650+ oxlint rules
mix volt.js.check    # format + lint for CI
mix volt.js.check --type-aware --type-check
```

Project-specific lint rules can be written in Elixir with `OXC.Lint.Rule`. Type-aware TypeScript rules can run through `tsgolint` with `--type-aware`.

JS/TS tests can be registered as ExUnit tests and run with the normal `mix test` command:

```elixir
# test/test_helper.exs
ExUnit.start(exclude: [:integration])
Volt.Test.ExUnit.install()
```

```ts
import { test, expect } from 'volt:test'

test('adds numbers', () => {
  expect(1 + 2).toBe(3)
})
```

See the [Testing guide](https://hexdocs.pm/volt/testing.html) for configuration and the supported API.

## Plugins

Extend the build pipeline with the `Volt.Plugin` behaviour. Plugins can turn custom file types into JavaScript and CSS, resolve virtual modules, transform parsed JavaScript and CSS ASTs, customize vendor prebundling, render final chunks, or call JS tooling through a QuickBEAM-powered embedded runtime:

```elixir
defmodule MyApp.MarkdownPlugin do
  @behaviour Volt.Plugin

  def name, do: "markdown"

  def compile(path, source, _opts) do
    if String.ends_with?(path, ".card.md") do
      html = Earmark.as_html!(source)

      {:ok,
       %Volt.Pipeline.Result{
         code: "export default #{Jason.encode!(html)};\n",
         css: ".markdown-card { padding: 1rem; border-radius: .75rem; }"
       }}
    end
  end
end
```

```elixir
config :volt, plugins: [MyApp.MarkdownPlugin]
```

See the [Plugins guide](https://hexdocs.pm/volt/plugins.html) for the full hook API.

## Documentation

Full documentation, guides, and cheatsheets on [HexDocs](https://hexdocs.pm/volt).

## License

MIT © 2026 Danila Poyarkov
