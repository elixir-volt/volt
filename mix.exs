defmodule Volt.MixProject do
  use Mix.Project

  @version "0.8.4"
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
      {:vize, "~> 0.8.0"},
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
      main: "Volt",
      extras: ["README.md"],
      source_ref: "v#{@version}"
    ]
  end
end
