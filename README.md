# Volt ⚡

[![Hex.pm](https://img.shields.io/hexpm/v/volt.svg)](https://hex.pm/packages/volt) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/volt)

Vite-level frontend tooling that runs inside the BEAM. One dep replaces esbuild, the Tailwind CLI, and Node.js with Rust NIFs powered by [OXC](https://oxc.rs) and [LightningCSS](https://lightningcss.dev).

```bash
mix igniter.install volt
mix phx.server
```

The installer configures everything. No binaries to download, no extra processes to manage.

## Why Volt

Phoenix ships with esbuild and a Tailwind CLI as separate binaries downloaded at compile time. They can't coordinate HMR or share work, and anything beyond vanilla JS requires Node.js.

Volt replaces both with a single Elixir dep. `mix phx.server` starts the frontend toolchain automatically, rebuilding Tailwind in ~40ms on template changes and hot-swapping JS modules via HMR. Compilation errors show as a browser overlay. Production builds finish in under 100ms.

You also get features you'd expect from Vite: code splitting, CSS Modules, `import.meta.glob()`, `.env` variables, static asset imports, import aliases, and `import.meta.hot` with state preservation.

## Installation

```bash
mix igniter.install volt
```

Or add the dep manually:

```elixir
def deps do
  [{:volt, "~> 0.10.0"}]
end
```

See the [Getting Started guide](https://hexdocs.pm/volt/getting-started.html) for manual configuration.

## Configuration

Standard `config/*.exs`. No `vite.config.js`, no `tailwind.config.js`:

```elixir
config :volt,
  entry: "assets/js/app.ts",
  target: :es2020,
  sourcemap: :hidden,
  tailwind: [
    css: "assets/css/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{js,ts,jsx,tsx}"}
    ]
  ]
```

`Volt.entry_path/1` resolves to the source file in dev and the content-hashed path in production, like `~p` for JS:

```heex
<script defer phx-track-static type="module" src={Volt.entry_path(@endpoint)}></script>
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

Tree-shaking, minification, code splitting, content-hashed filenames, and source maps. Ready for `mix phx.digest`.

## Framework support

Vue SFCs with scoped CSS, React JSX with the automatic runtime, and Svelte 5 with runes all compile without Node.js installed. Plain TypeScript with LiveView hooks works too.

See the [examples](https://github.com/elixir-volt/volt/tree/master/examples) for complete Phoenix projects with each framework.

## Developer tools

JS/TS formatting and linting run as Rust NIFs. `mix format` handles Elixir and JavaScript together:

```elixir
# .formatter.exs
[plugins: [Volt.Formatter], inputs: ["assets/**/*.{js,ts,jsx,tsx}"]]
```

```bash
mix format           # Elixir + JS/TS
mix volt.lint        # 650+ oxlint rules
mix volt.js.check    # format + lint for CI
```

## Plugins

Extend the build pipeline with the `Volt.Plugin` behaviour:

```elixir
defmodule MyApp.MarkdownPlugin do
  @behaviour Volt.Plugin

  def name, do: "markdown"

  def load(path) do
    if String.ends_with?(path, ".md") do
      html = path |> File.read!() |> Earmark.as_html!()
      {:ok, "export default #{Jason.encode!(html)};\n"}
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
