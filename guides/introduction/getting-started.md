# Getting Started

## Automatic Setup

```bash
mix igniter.install volt
```

The installer:
- Adds `{:volt, "~> 0.16"}` to `mix.exs`
- Configures build settings in `config/config.exs`
- Adds format and lint config to `config/config.exs`
- Adds `Volt.Formatter` plugin to `.formatter.exs`
- Adds the `Volt.DevServer` plug to your endpoint
- Configures Volt's automatic development watcher
- Updates `assets.build` and `assets.deploy` aliases
- Removes `esbuild` and `tailwind` deps if present

Start the server:

```bash
mix phx.server
```

## Manual Setup

Add Volt to your dependencies:

```elixir
def deps do
  [{:volt, "~> 0.16"}]
end
```

### Build Configuration

```elixir
# config/config.exs
config :volt,
  entry: "assets/js/app.ts",
  root: "assets",
  sources: ["**/*.{js,ts,jsx,tsx}"],
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

### Dev Server and Watcher

Add the dev server plug to your endpoint (inside the `code_reloading?` block, after `Phoenix.CodeReloader`). The plug starts its supervised file watcher automatically when it receives the first development request:

```elixir
# lib/my_app_web/endpoint.ex
if code_reloading? do
  # ...
  plug Volt.DevServer, root: "assets"
end
```

Configure any additional directories that should participate in Tailwind rebuilds:

```elixir
# config/dev.exs
config :volt, :server,
  prefix: "/assets",
  watch_dirs: ["lib/"]
```

No Phoenix `:watchers` entry or separate OS process is required. `mix volt.dev` remains available for standalone or non-Phoenix workflows. Set `watch: false` in the server configuration to disable automatic watching.

### Layout Tags

In your root layout, add both the CSS link and the JS script tag:

```heex
<link phx-track-static rel="stylesheet" href={Volt.static_path(MyAppWeb.Endpoint, "/assets/css/app.css")} />
<script defer phx-track-static type="module" src={Volt.static_path(MyAppWeb.Endpoint, "/assets/js/app.js")}></script>
```

### Mix Aliases

Update your build aliases in `mix.exs`:

```elixir
defp aliases do
  [
    "assets.build": ["volt.build --tailwind"],
    "assets.deploy": ["volt.build --tailwind", "phx.digest"]
  ]
end
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

```text
Building Tailwind CSS...
  app-1a2b3c4d.css  23.9 KB
Built Tailwind in 43ms
Building "assets/js/app.ts"...
  app-5e6f7a8b.js  128.4 KB
  manifest.json  2 entries
Built in 15ms
```

See [Production Builds](../deployment/production-builds.md) for all options.
