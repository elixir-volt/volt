defmodule ReactExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :react_example,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {ReactExample.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.4"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:volt, path: "../..", override: true}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "npm.install", "assets.build"],
      "assets.build": ["volt.build --tailwind --no-hash --no-minify"],
      "assets.deploy": ["volt.build --tailwind --no-hash", "phx.digest"],
      precommit: ["compile --warnings-as-errors", "format", "test"]
    ]
  end
end
