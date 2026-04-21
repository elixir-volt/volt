if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Volt.Install do
    @shortdoc "Install and configure Volt in a Phoenix project"

    @moduledoc """
    #{@shortdoc}

    Replaces esbuild and tailwind with Volt — no Node.js required.

    ## Example

        mix igniter.install volt

    This installer will:

    1. Remove `:esbuild` and `:tailwind` deps
    2. Add Volt build config to `config/config.exs`
    3. Add format and lint config to `config/config.exs`
    4. Add `Volt.DevServer` plug to your endpoint
    5. Add the Volt watcher to `config/dev.exs`

    You may need to manually remove old `config :esbuild` and
    `config :tailwind` blocks from `config/config.exs`.
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :volt,
        example: "mix igniter.install volt"
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app_name = Igniter.Project.Application.app_name(igniter)

      igniter
      |> remove_old_deps()
      |> warn_about_old_config()
      |> add_volt_config()
      |> add_format_config()
      |> add_lint_config()
      |> add_dev_config(app_name)
      |> add_dev_server_plug()
    end

    # ── Remove old tooling ──

    defp remove_old_deps(igniter) do
      igniter
      |> Igniter.Project.Deps.remove_dep(:esbuild)
      |> Igniter.Project.Deps.remove_dep(:tailwind)
    end

    defp warn_about_old_config(igniter) do
      has_esbuild =
        Igniter.Project.Config.configures_root_key?(igniter, "config.exs", :esbuild)

      has_tailwind =
        Igniter.Project.Config.configures_root_key?(igniter, "config.exs", :tailwind)

      cond do
        has_esbuild and has_tailwind ->
          Igniter.add_warning(igniter, """
          Found `config :esbuild` and `config :tailwind` in config/config.exs.
          Please remove them manually — Volt replaces both.
          Also remove esbuild/tailwind watchers from config/dev.exs.
          """)

        has_esbuild ->
          Igniter.add_warning(igniter, """
          Found `config :esbuild` in config/config.exs.
          Please remove it manually — Volt replaces esbuild.
          Also remove the esbuild watcher from config/dev.exs.
          """)

        has_tailwind ->
          Igniter.add_warning(igniter, """
          Found `config :tailwind` in config/config.exs.
          Please remove it manually — Volt replaces the Tailwind CLI.
          Also remove the tailwind watcher from config/dev.exs.
          """)

        true ->
          igniter
      end
    end

    # ── Add Volt config ──

    defp add_volt_config(igniter) do
      igniter
      |> Igniter.Project.Config.configure("config.exs", :volt, [:entry], "assets/js/app.ts")
      |> Igniter.Project.Config.configure("config.exs", :volt, [:outdir], "priv/static/assets")
      |> Igniter.Project.Config.configure("config.exs", :volt, [:target], :es2020)
      |> Igniter.Project.Config.configure("config.exs", :volt, [:sourcemap], :hidden)
      |> Igniter.Project.Config.configure(
        "config.exs",
        :volt,
        [:tailwind],
        {:code,
         Sourceror.parse_string!("""
         [
           css: "assets/css/app.css",
           sources: [
             %{base: "lib/", pattern: "**/*.{ex,heex}"},
             %{base: "assets/", pattern: "**/*.{js,ts,jsx,tsx}"}
           ]
         ]
         """)}
      )
    end

    defp add_format_config(igniter) do
      opts = Volt.JS.Format.load_json_config()

      format_kw =
        Keyword.merge(
          [
            print_width: 100,
            semi: false,
            single_quote: true,
            trailing_comma: :none,
            arrow_parens: :always
          ],
          opts
        )

      code = Enum.map_join(format_kw, ",\n  ", fn {k, v} -> "#{k}: #{inspect(v)}" end)

      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        :volt,
        [:format],
        {:code, Sourceror.parse_string!("[\n  #{code}\n]")}
      )
    end

    defp add_lint_config(igniter) do
      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        :volt,
        [:lint],
        {:code,
         Sourceror.parse_string!("""
         [
           plugins: [:typescript],
           rules: %{
             "no-debugger" => :deny,
             "eqeqeq" => :deny
           }
         ]
         """)}
      )
    end

    defp add_dev_config(igniter, app_name) do
      endpoint = endpoint_module(igniter)

      Igniter.Project.Config.configure(
        igniter,
        "dev.exs",
        app_name,
        [endpoint, :watchers, :volt],
        {:code,
         Sourceror.parse_string!("""
         {Mix.Tasks.Volt.Dev, :run, [~w(--tailwind)]}
         """)}
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        :volt,
        [:server, :prefix],
        "/assets"
      )
      |> Igniter.Project.Config.configure(
        "dev.exs",
        :volt,
        [:server, :watch_dirs],
        {:code, Sourceror.parse_string!(~s(["lib/"]))}
      )
    end

    # ── DevServer plug ──

    defp add_dev_server_plug(igniter) do
      {igniter, endpoint} =
        Igniter.Libs.Phoenix.select_endpoint(
          igniter,
          nil,
          "Which endpoint should serve Volt assets?"
        )

      if endpoint do
        Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
          with :error <-
                 Igniter.Code.Common.move_to(zipper, fn z ->
                   Igniter.Code.Function.function_call?(z, :plug) and
                     Igniter.Code.Function.argument_equals?(z, 0, Volt.DevServer)
                 end),
               {:ok, zipper} <- Igniter.Code.Common.move_to(zipper, &code_reloading?/1) do
            {:ok,
             Igniter.Code.Common.add_code(
               zipper,
               """
               plug Volt.DevServer, root: "assets"
               """,
               placement: :after
             )}
          else
            {:ok, _} ->
              {:ok, zipper}

            :error ->
              {:warning,
               """
               Could not find the code_reloading? section in `#{inspect(endpoint)}`.
               Please add the plug manually inside `if code_reloading? do`:

                 plug Volt.DevServer, root: "assets"
               """}
          end
        end)
      else
        Igniter.add_warning(igniter, """
        No endpoint found. Please add the Volt dev server plug manually:

          plug Volt.DevServer, root: "assets"
        """)
      end
    end

    # ── Helpers ──

    defp code_reloading?(zipper) do
      Igniter.Code.Function.function_call?(zipper, :if, 2) &&
        Igniter.Code.Function.argument_matches_predicate?(
          zipper,
          0,
          &Igniter.Code.Common.variable?(&1, :code_reloading?)
        )
    end

    defp endpoint_module(igniter) do
      app_name = Igniter.Project.Application.app_name(igniter)

      app_name
      |> to_string()
      |> Macro.camelize()
      |> then(&Module.concat([String.to_atom("#{&1}Web"), Endpoint]))
    end
  end
else
  defmodule Mix.Tasks.Volt.Install do
    @shortdoc "Install and configure Volt (requires igniter)"

    @moduledoc false

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'volt.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
