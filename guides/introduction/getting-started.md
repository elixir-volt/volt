# Getting Started

## Automatic Setup

```bash
mix igniter.install volt
```

The installer:
- Adds `{:volt, "~> 0.9"}` to `mix.exs`
- Configures build settings in `config/config.exs`
- Adds format and lint config to `config/config.exs`
- Adds `Volt.Formatter` plugin to `.formatter.exs`
- Adds the `Volt.DevServer` plug to your endpoint
- Adds the Volt watcher to `config/dev.exs`
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
  [{:volt, "~> 0.9"}]
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

Add the dev server plug to your endpoint (inside the `code_reloading?` block, after `Phoenix.CodeReloader`):

```elixir
# lib/my_app_web/endpoint.ex
if code_reloading? do
  # ...
  plug Volt.DevServer, root: "assets"
end
```

Configure the dev server and add the watcher:

```elixir
# config/dev.exs
config :volt, :server,
  prefix: "/assets",
  watch_dirs: ["lib/"]

config :my_app, MyAppWeb.Endpoint,
  watchers: [
    volt: {Mix.Tasks.Volt.Dev, :run, [~w(--tailwind)]}
  ]
```

The watcher starts `mix volt.dev` automatically when `mix phx.server` runs, watching for file changes and triggering HMR updates and Tailwind rebuilds.

### Layout Tags

In your root layout, add both the CSS link and the JS script tag:

```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
<script defer phx-track-static type="module" src={Volt.entry_path(MyAppWeb.Endpoint)}></script>
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
