defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo,
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
      mod: {Demo.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8.4"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:volt, path: "../.."},
      {:phoenix_vapor, path: "../../../phoenix_vapor"},
      {:oxc, path: "../../../oxc_ex", override: true},
      {:vize, path: "../../../vize_ex", override: true},
      {:quickbeam, path: "../../../quickbeam", override: true},
      {:oxide_ex, path: "../../../oxide_ex", override: true},
      {:rustler, ">= 0.0.0", optional: true}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.build"],
      "assets.build": [
        "compile",
        "volt.build --entry assets/js/app.ts --outdir priv/static/assets --resolve-dir deps --no-minify --no-hash --tailwind --tailwind-css assets/css/app.css"
      ],
      "assets.deploy": [
        "volt.build --entry assets/js/app.ts --outdir priv/static/assets --resolve-dir deps --no-hash --tailwind --tailwind-css assets/css/app.css",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
