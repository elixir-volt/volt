# Getting Started

## Automatic Setup

```bash
mix igniter.install volt
```

The installer:
- Adds `{:volt, "~> 0.9"}` to `mix.exs`
- Configures build settings in `config/config.exs`
- Adds the dev server plug to your endpoint
- Sets up the file watcher in `config/dev.exs`
- Configures `mix format` with `Volt.Formatter`
- Removes `esbuild` and `tailwind` deps if present

Start the server:

```bash
mix phx.server
```

## Manual Setup

Add Volt to your dependencies:

```elixir
def deps do
  [{:volt, "~> 0.9"}]
end
```

### Build Configuration

All config lives in your standard `config/*.exs` files:

```elixir
# config/config.exs
config :volt,
  entry: "assets/js/app.ts",
  root: "assets",
  sources: ["**/*.{js,ts,jsx,tsx,vue}"],
  ignore: ["node_modules/**", "vendor/**"],
  target: :es2020,
  tailwind: [
    css: "assets/css/app.css",
    sources: [
      %{base: "lib/", pattern: "**/*.{ex,heex}"},
      %{base: "assets/", pattern: "**/*.{vue,ts,tsx}"}
    ]
  ]
```

### Dev Server

Add the dev server plug to your endpoint (before `Plug.Static`):

```elixir
# lib/my_app_web/endpoint.ex
if code_reloading? do
  plug Volt.DevServer
end
```

Configure the watcher:

```elixir
# config/dev.exs
config :volt, :server,
  prefix: "/assets",
  watch_dirs: ["lib/", "assets/"]
```

### Script Tag

In your root layout:

```heex
<script defer phx-track-static type="module" src={Volt.entry_path(MyAppWeb.Endpoint)}></script>
```

### Formatting

Add `Volt.Formatter` to `.formatter.exs`:

```elixir
[
  plugins: [Volt.Formatter],
  inputs: [
    "{mix,.formatter}.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "assets/**/*.{js,ts,jsx,tsx}"
  ]
]
```

## Production Build

```bash
mix volt.build
```

```
Building Tailwind CSS...
  app-1a2b3c4d.css  23.9 KB
Built Tailwind in 43ms
Building "assets/js/app.ts"...
  app-5e6f7a8b.js  128.4 KB
  manifest.json  2 entries
Built in 15ms
```

See [Production Builds](../deployment/production-builds.md) for all options.
