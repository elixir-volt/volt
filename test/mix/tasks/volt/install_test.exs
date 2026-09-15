defmodule Mix.Tasks.Volt.InstallTest do
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
                tailwind: {Tailwind, :install_and_run, [:demo, ~w(--watch)]},
                volt: {Mix.Tasks.Volt.Dev, :run, [~w(--tailwind)]}
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
      refute dev_content =~ "volt:"
      refute dev_content =~ "Mix.Tasks.Volt.Dev"

      endpoint_content =
        igniter.rewrite.sources["lib/demo_web/endpoint.ex"]
        |> Rewrite.Source.get(:content)

      assert endpoint_content =~
               "if code_reloading? do\n    plug(Phoenix.CodeReloader)\n" <>
                 "    plug(Volt.DevServer, root: \"assets\")\n  end"

      mix_content =
        igniter.rewrite.sources["mix.exs"]
        |> Rewrite.Source.get(:content)

      tsconfig =
        igniter.rewrite.sources["tsconfig.json"]
        |> Rewrite.Source.get(:content)
        |> Jason.decode!()

      assert tsconfig["compilerOptions"]["strict"]
      assert "deps/volt/priv/types/client/**/*.d.ts" in tsconfig["include"]

      assert mix_content =~ ~s("assets.setup": [])
      assert mix_content =~ ~s("assets.build": ["compile", "volt.build --tailwind"])
      assert mix_content =~ ~s("assets.deploy": ["volt.build --tailwind", "phx.digest"])
    end

    test "preserves options, exclusions and explicit files while adding client types once" do
      original = %{
        "compilerOptions" => %{"strict" => false},
        "exclude" => ["deps"],
        "files" => ["assets/app.ts"]
      }

      igniter = install_with_config("tsconfig.json", Jason.encode!(original))
      config = config(igniter, "tsconfig.json")
      assert config["compilerOptions"] == original["compilerOptions"]
      assert config["exclude"] == ["deps"]
      refute Map.has_key?(config, "include")

      assert config["files"] == [
               "assets/app.ts",
               "deps/volt/priv/types/client/hmr.d.ts",
               "deps/volt/priv/types/client/preload.d.ts",
               "deps/volt/priv/types/client/styles.d.ts"
             ]

      assert config(Mix.Tasks.Volt.Install.igniter(igniter), "tsconfig.json") == config
    end

    test "retains default source discovery when adding explicit declaration files" do
      config =
        install_with_config("tsconfig.json", ~s({"compilerOptions":{"strict":true}}))
        |> config("tsconfig.json")

      assert config["include"] == ["**/*"]
    end

    test "keeps an authored include list" do
      config =
        install_with_config("tsconfig.json", ~s({"include":["src/**/*.ts"]}))
        |> config("tsconfig.json")

      assert config["include"] == ["src/**/*.ts"]
    end

    test "updates an assets configuration with paths relative to that configuration" do
      igniter = install_with_config("assets/tsconfig.json", ~s({"include":["**/*.ts"]}))
      refute Map.has_key?(igniter.rewrite.sources, "tsconfig.json")

      assert "../deps/volt/priv/types/client/hmr.d.ts" in config(igniter, "assets/tsconfig.json")[
               "files"
             ]
    end

    test "leaves JSONC and inherited or referenced configurations untouched with guidance" do
      for content <- [
            "{ // preserve this comment\n}",
            ~s({"extends":"./base.json"}),
            ~s({"references":[{"path":"./assets"}]})
          ] do
        igniter = install_with_config("tsconfig.json", content)
        assert Rewrite.Source.get(igniter.rewrite.sources["tsconfig.json"], :content) == content
        assert Enum.any?(igniter.warnings, &String.contains?(&1, "manual configuration"))
      end
    end
  end

  defp install_with_config(path, content) do
    Test.test_project(app_name: :demo, files: %{path => content})
    |> Mix.Tasks.Volt.Install.igniter()
  end

  defp config(igniter, path) do
    igniter.rewrite.sources[path] |> Rewrite.Source.get(:content) |> Jason.decode!()
  end
end
