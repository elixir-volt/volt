# Volt

Elixir-native frontend build tool — dev server, HMR, and production builds
for JavaScript, TypeScript, Vue SFCs, and CSS. No Node.js required at runtime.

Powered by [OXC](https://hex.pm/packages/oxc) and [Vize](https://hex.pm/packages/vize) Rust NIFs.

## Installation

```elixir
def deps do
  [{:volt, "~> 0.1.0"}]
end
```

## Dev Server

Add the Plug to your Phoenix endpoint (or any Plug-based app):

```elixir
# lib/my_app_web/endpoint.ex
if code_reloading? do
  plug Volt.DevServer,
    root: "assets/src",
    prefix: "/assets",
    target: "es2020"
end
```

The dev server compiles files on demand:

- `.ts`, `.tsx`, `.js`, `.jsx` → compiled via OXC with sourcemaps
- `.vue` → compiled via Vize (script + template + scoped CSS)
- `.css` → processed via LightningCSS (autoprefixing, minification)

Results are cached by file mtime — unchanged files are served instantly.
Compilation errors show an in-browser error overlay.

## Compilation Pipeline

Use `Volt.Pipeline` directly for programmatic access:

```elixir
{:ok, result} = Volt.Pipeline.compile("app.ts", "const x: number = 42")
result.code       # "const x = 42;\n"
result.sourcemap  # "{\"version\":3, ...}"

{:ok, result} = Volt.Pipeline.compile("App.vue", sfc_source)
result.code    # compiled JavaScript
result.css     # scoped CSS
result.hashes  # %{template: "abc...", style: "def...", script: "ghi..."}
```

## Stack

```
volt
├── oxc    — JS/TS parse, transform, minify, bundle
├── vize   — Vue SFC compilation, Vapor IR, CSS (LightningCSS)
└── plug   — HTTP serving
```

## License

MIT © 2026 Danila Poyarkov
