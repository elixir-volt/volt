defmodule Volt.MixProject do
  use Mix.Project

  @version "0.9.2"
  @source_url "https://github.com/elixir-volt/volt"

  def project do
    [
      app: :volt,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix]],
      name: "Volt",
      description:
        "Elixir-native frontend build tool — dev server, HMR, and production builds powered by OXC and Vize.",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Volt.Application, []}
    ]
  end

  defp deps do
    [
      {:reach, "~> 1.6"},
      {:oxc, "~> 0.11.0"},
      {:vize, "~> 0.10.0"},
      {:oxide_ex, "~> 0.2.0"},
      {:quickbeam, "~> 0.10.6"},
      {:dotenvy, "~> 1.1"},
      {:floki, "~> 0.38"},
      {:plug, "~> 1.16"},
      {:websock_adapter, "~> 0.5"},
      {:file_system, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.5", optional: true},
      {:npm, "~> 0.6.0"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.2", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:bandit, "~> 1.0", only: :test},
      {:playwright_ex, "~> 0.5", only: :test}
    ]
  end

  defp aliases do
    [
      lint: [
        "format --check-formatted",
        "volt.js.check",
        "credo --strict",
        "ex_dna",
        "dialyzer"
      ],
      setup: ["deps.get"],
      ci: ["lint", "cmd MIX_ENV=test mix test"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w[lib priv mix.exs README.md LICENSE]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/introduction/getting-started.md",
        "guides/introduction/why-volt.md",
        "guides/features/features.md",
        "guides/features/frameworks.md",
        "guides/features/tailwind.md",
        "guides/features/hmr.md",
        "guides/features/code-splitting.md",
        "guides/features/css-modules.md",
        "guides/features/static-assets.md",
        "guides/features/environment-variables.md",
        "guides/features/glob-imports.md",
        "guides/features/plugins.md",
        "guides/features/formatting-and-linting.md",
        "guides/deployment/production-builds.md",
        "guides/migration/from-esbuild.md",
        "guides/cheatsheets/configuration.cheatmd",
        "guides/cheatsheets/cli.cheatmd"
      ],
      groups_for_extras: [
        Introduction: ~r/guides\/introduction\//,
        Features: ~r/guides\/features\//,
        Deployment: ~r/guides\/deployment\//,
        Migration: ~r/guides\/migration\//,
        Cheatsheets: ~r/guides\/cheatsheets\//
      ],
      groups_for_modules: [
        "Core": [Volt, Volt.Pipeline, Volt.Config],
        "Dev Server": [Volt.DevServer, Volt.Watcher, Volt.Dev.ConsoleForwarder],
        "HMR": [Volt.HMR.Boundary, Volt.HMR.Client, Volt.HMR.Socket],
        "Production Build": [Volt.Builder, Volt.ChunkGraph, Volt.Preload],
        "Tailwind CSS": [Volt.Tailwind],
        "CSS": [Volt.CSS.Modules],
        "Plugins": [Volt.Plugin, Volt.Plugin.Vue, Volt.Plugin.Svelte, Volt.Plugin.React, Volt.PluginRunner],
        "JavaScript": [Volt.JS.Runtime, Volt.JS.GlobImport, Volt.JS.PackageResolver, Volt.Env, Volt.Assets],
        "Formatting": [Volt.Formatter],
        "Mix Tasks": [Mix.Tasks.Volt.Build, Mix.Tasks.Volt.Dev, Mix.Tasks.Volt.Lint, Mix.Tasks.Volt.Js.Format, Mix.Tasks.Volt.Js.Check, Mix.Tasks.Volt.Install]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
