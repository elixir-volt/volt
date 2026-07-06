defmodule Volt.MixProject do
  use Mix.Project

  @version "0.14.12"
  @source_url "https://github.com/elixir-volt/volt"

  def project do
    [
      app: :volt,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:mix], flags: [:no_opaque]],
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
      {:reach, "~> 2.6.1", only: [:dev, :test], runtime: false},
      {:glob_ex, "~> 0.1"},
      {:oxc, "~> 0.17.1"},
      {:vize, "~> 0.13.0"},
      {:oxide_ex, "~> 0.2.1"},
      {:quickbeam, "~> 0.10.18"},
      {:dotenvy, "~> 1.1"},
      {:floki, "~> 0.38"},
      {:plug, "~> 1.16"},
      {:mime, "~> 2.0"},
      {:websock_adapter, "~> 0.5"},
      {:file_system, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:json_codec, "~> 0.1.5"},
      {:igniter, "~> 0.5", optional: true},
      {:npm, "~> 0.7.4"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:makeup_js, "~> 0.1", only: :dev, runtime: false},
      {:bandit, "~> 1.0", only: :test},
      {:playwright_ex, "~> 0.5", only: :test}
    ]
  end

  defp aliases do
    [
      lint: [
        "format --check-formatted",
        "volt.js.check --type-aware --type-check",
        "credo --strict",
        "ex_dna --min-mass 20",
        "reach.check --arch --dead-code --smells --strict",
        "dialyzer"
      ],
      setup: ["deps.get"],
      ci: ["lint", "cmd env MIX_ENV=test mix test"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w[lib priv guides mix.exs README.md CHANGELOG.md LICENSE]
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
        "guides/features/testing.md",
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
        Core: [Volt, Volt.Preload, Volt.Config, Volt.Plugin],
        "Dev Server": [Volt.DevServer, Volt.Watcher, Volt.HMR, Volt.Dev.ConsoleForwarder],
        "Production Build": [Volt.Builder, Volt.ChunkGraph, Volt.PublicDir],
        "Tailwind CSS": [Volt.Tailwind],
        CSS: [Volt.CSS.Modules],
        Plugins: [
          Volt.Plugin.Vue,
          Volt.Plugin.Svelte,
          Volt.Plugin.React,
          Volt.Plugin.Solid,
          Volt.Plugin.EmbeddedModule,
          Volt.Plugin.Helpers,
          Volt.PluginRunner
        ],
        JavaScript: [
          Volt.Assets,
          Volt.Env,
          Volt.JS.Runtime,
          Volt.JS.Format,
          Volt.Priv
        ],
        Formatting: [Volt.Formatter, Volt.Format],
        Testing: [
          Volt.Test.Assertions,
          Volt.Test.Bundle,
          Volt.Test.Bundler,
          Volt.Test.Config,
          Volt.Test.Discovery,
          Volt.Test.ExUnit,
          Volt.Test.Imports,
          Volt.Test.Lines,
          Volt.Test.Runner,
          Volt.Test.Sigils
        ],
        "Mix Tasks": [
          Mix.Tasks.Volt.Build,
          Mix.Tasks.Volt.Dev,
          Mix.Tasks.Volt.Lint,
          Mix.Tasks.Volt.Js.Format,
          Mix.Tasks.Volt.Js.Check,
          Mix.Tasks.Volt.Install
        ],
        "Internals: Builder": [
          Volt.Builder.Collector,
          Volt.Builder.Collector.State,
          Volt.Builder.Context,
          Volt.Builder.BuildContext,
          Volt.Builder.Dependencies,
          Volt.Builder.Externals,
          Volt.Builder.Output,
          Volt.Builder.OutputContext,
          Volt.Builder.OutputFile,
          Volt.Builder.Resolver,
          Volt.Builder.Result,
          Volt.Builder.Rewriter,
          Volt.Builder.Writer,
          Volt.HTMLEntry,
          Volt.Pipeline,
          Volt.Pipeline.Result
        ],
        "Internals: Config": [
          Volt.Config.Build,
          Volt.Config.Profile,
          Volt.Config.Server
        ],
        "Internals: CSS": [
          Volt.MIME,
          Volt.CSS.AST,
          Volt.CSS.AssetURLRewriter
        ],
        "Internals: Dev Server": [
          Volt.Cache,
          Volt.DevServer.CacheEntry,
          Volt.DevServer.Config
        ],
        "Internals: HMR": [
          Volt.HMR.Boundary,
          Volt.HMR.GlobGraph,
          Volt.HMR.ImportGraph,
          Volt.HMR.Message,
          Volt.HMR.StyleDependencies,
          Volt.HMR.StyleGraph,
          Volt.HMR.ModuleGraph,
          Volt.HMR.ModuleGraph.Node,
          Volt.HMR.Socket
        ],
        "Internals: JavaScript": [
          Volt.Assets.Query,
          Volt.JS.Asset,
          Volt.JS.AST,
          Volt.JS.Extensions,
          Volt.JS.Helpers,
          Volt.JS.ImportExtractor,
          Volt.JS.ImportExtractor.Result,
          Volt.JS.Patch,
          Volt.JS.PrebundleEntry,
          Volt.JS.PrebundleEntry.Export,
          Volt.JS.PrebundleEntry.Import,
          Volt.JS.Resolution,
          Volt.JS.Resolver,
          Volt.JS.Runtime.Bundler,
          Volt.JS.Runtime.Entry,
          Volt.JS.Runtime.Error,
          Volt.JS.Runtime.Installer,
          Volt.JS.Transforms.AssetURLs,
          Volt.JS.Transforms.DynamicImports,
          Volt.JS.Transforms.DynamicImports.Replacement,
          Volt.JS.Transforms.GlobImports,
          Volt.JS.Transforms.GlobImports.Call,
          Volt.JS.Transforms.GlobImports.File,
          Volt.JS.Transforms.ImportMetaEnv,
          Volt.JS.Transforms.Imports,
          Volt.JS.Transforms.Specifiers,
          Volt.JS.Transforms.Workers,
          Volt.JS.TSConfig,
          Volt.JS.Vendor
        ],
        "Internals: Support": [
          Volt.Application,
          Volt.ETS,
          Volt.Path,
          Volt.Tailwind.Loader,
          Volt.Tailwind.Resolver,
          Volt.URL
        ],
        "Internals: Plugin Options": [
          Volt.Plugin.Solid.CompilerOptions,
          Volt.Plugin.Solid.CompilerOptions.SolidOptions,
          Volt.Plugin.Svelte.CompilerOptions
        ]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
