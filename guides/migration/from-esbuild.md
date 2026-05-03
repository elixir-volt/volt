# Migrating from esbuild

The easiest way to migrate is the installer:

```bash
mix igniter.install volt
```

It automatically removes `esbuild` and `tailwind` deps and replaces them with Volt configuration.

## Manual Migration

### 1. Replace Dependencies

Remove from `mix.exs`:

```elixir
{:esbuild, "~> 0.8"},
{:tailwind, "~> 0.2"}
```

Add:

```elixir
{:volt, "~> 0.9"}
```

### 2. Replace Config

Remove `config :esbuild` and `config :tailwind` blocks from `config/config.exs`.

Add Volt config (see [Getting Started](../introduction/getting-started.md)).

### 3. Replace Endpoint Plug

Remove the esbuild/tailwind watchers from `config/dev.exs` and add the Volt dev server plug to your endpoint.

### 4. Replace Build Aliases

Update `assets.build` and `assets.deploy` in `mix.exs`:

```elixir
"assets.build": ["volt.build --tailwind"],
"assets.deploy": ["volt.build --tailwind", "phx.digest"]
```

### 5. Remove Binaries

Delete any cached esbuild/tailwind binaries:

```bash
rm -rf _build/esbuild* _build/tailwind*
```
