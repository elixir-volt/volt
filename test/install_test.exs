defmodule Volt.InstallTest do
  use ExUnit.Case

  alias Igniter.Test

  describe "volt.install" do
    test "removes esbuild and tailwind config and updates aliases" do
      igniter =
        Test.test_project(
          app_name: :demo,
          files: %{
            "config/config.exs" => """
            import Config

            config :demo, DemoWeb.Endpoint,
              url: [host: "localhost"]

            config :esbuild,
              version: "0.25.4",
              demo: [args: ~w(js/app.js --bundle), cd: Path.expand("../assets", __DIR__)]

            config :tailwind,
              version: "4.1.12",
              demo: [args: ~w(--input=assets/css/app.css)]

            import_config "\#{config_env()}.exs"
            """,
            "config/dev.exs" => """
            import Config

            config :demo, DemoWeb.Endpoint,
              http: [ip: {127, 0, 0, 1}, port: 4000],
              watchers: [
                esbuild: {Esbuild, :install_and_run, [:demo, ~w(--watch)]},
                tailwind: {Tailwind, :install_and_run, [:demo, ~w(--watch)]}
              ]

            config :demo, DemoWeb.Endpoint,
              live_reload: [patterns: [~r"priv/static/.*"]]
            """,
            "lib/demo_web/endpoint.ex" => """
            defmodule DemoWeb.Endpoint do
              use Phoenix.Endpoint, otp_app: :demo

              if code_reloading? do
                plug Phoenix.CodeReloader
              end

              plug DemoWeb.Router
            end
            """,
            "lib/demo_web/router.ex" => """
            defmodule DemoWeb.Router do
              use DemoWeb, :router
            end
            """,
            "lib/demo_web.ex" => """
            defmodule DemoWeb do
              def router do
                quote do
                  use Phoenix.Router
                end
              end
            end
            """,
            "mix.exs" => """
            defmodule Demo.MixProject do
              use Mix.Project

              def project do
                [
                  app: :demo,
                  version: "0.1.0",
                  elixir: "~> 1.17",
                  deps: deps(),
                  aliases: aliases()
                ]
              end

              def application do
                [mod: {Demo.Application, []}, extra_applications: [:logger]]
              end

              defp deps do
                [
                  {:phoenix, "~> 1.7"},
                  {:esbuild, "~> 0.10"},
                  {:tailwind, "~> 0.3"}
                ]
              end

              defp aliases do
                [
                  setup: ["deps.get", "assets.setup", "assets.build"],
                  "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
                  "assets.build": ["compile", "tailwind demo", "esbuild demo"],
                  "assets.deploy": ["tailwind demo --minify", "esbuild demo --minify", "phx.digest"]
                ]
              end
            end
            """
          }
        )
        |> Mix.Tasks.Volt.Install.igniter()

      config_content =
        igniter.rewrite.sources["config/config.exs"]
        |> Rewrite.Source.get(:content)

      refute config_content =~ "config :esbuild"
      refute config_content =~ "config :tailwind"

      dev_content =
        igniter.rewrite.sources["config/dev.exs"]
        |> Rewrite.Source.get(:content)

      refute dev_content =~ "esbuild:"
      refute dev_content =~ "tailwind:"
      assert dev_content =~ "volt:"

      mix_content =
        igniter.rewrite.sources["mix.exs"]
        |> Rewrite.Source.get(:content)

      assert mix_content =~ ~s("assets.setup": [])
      assert mix_content =~ ~s("assets.build": ["compile", "volt.build --tailwind"])
      assert mix_content =~ ~s("assets.deploy": ["volt.build --tailwind", "phx.digest"])
    end
  end
end
