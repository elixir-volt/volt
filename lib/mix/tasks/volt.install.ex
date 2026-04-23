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
    2. Remove `config :esbuild` and `config :tailwind` blocks
    3. Update `assets.setup`, `assets.build`, and `assets.deploy` aliases
    4. Add Volt build config to `config/config.exs`
    5. Add format and lint config to `config/config.exs`
    6. Add `Volt.Formatter` plugin to `.formatter.exs`
    7. Add `Volt.DevServer` plug to your endpoint
    8. Add the Volt watcher to `config/dev.exs`
    """

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Code.Keyword, as: CodeKeyword
    alias Igniter.Code.List
    alias Igniter.Code.Tuple
    alias Igniter.Project.Config, as: ProjectConfig
    alias Igniter.Project.Deps, as: ProjectDeps
    alias Igniter.Project.Formatter, as: ProjectFormatter
    alias Igniter.Project.TaskAliases

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
      endpoint = endpoint_module(igniter)

      igniter
      |> remove_old_deps()
      |> remove_old_config()
      |> remove_old_watchers(app_name, endpoint)
      |> update_aliases()
      |> add_volt_config()
      |> add_format_config()
      |> add_lint_config()
      |> add_formatter_plugin()
      |> add_dev_config(app_name, endpoint)
      |> add_dev_server_plug()
    end

    # ── Remove old tooling ──

    defp remove_old_deps(igniter) do
      igniter
      |> ProjectDeps.remove_dep(:esbuild)
      |> ProjectDeps.remove_dep(:tailwind)
    end

    defp remove_old_config(igniter) do
      igniter
      |> ProjectConfig.remove_application_configuration("config.exs", :esbuild)
      |> ProjectConfig.remove_application_configuration("config.exs", :tailwind)
      |> ProjectConfig.remove_application_configuration("dev.exs", :esbuild)
      |> ProjectConfig.remove_application_configuration("dev.exs", :tailwind)
    end

    defp remove_old_watchers(igniter, app_name, endpoint) do
      Igniter.update_elixir_file(
        igniter,
        "config/dev.exs",
        fn zipper ->
          with {:ok, config_zipper} <-
                 Common.move_to(zipper, &endpoint_config?(&1, app_name, endpoint)),
               {:ok, keyword_zipper} <- Function.move_to_nth_argument(config_zipper, 2),
               {:ok, watchers_zipper} <- CodeKeyword.get_key(keyword_zipper, :watchers),
               {:ok, updated} <- List.remove_from_list(watchers_zipper, &old_watcher?/1) do
            {:ok, updated}
          else
            _ -> {:ok, zipper}
          end
        end,
        required?: false
      )
    end

    defp endpoint_config?(zipper, app_name, endpoint) do
      Function.function_call?(zipper, :config, 3) and
        Function.argument_equals?(zipper, 0, app_name) and
        Function.argument_equals?(zipper, 1, endpoint)
    end

    defp old_watcher?(item) do
      Tuple.elem_equals?(item, 0, :esbuild) or Tuple.elem_equals?(item, 0, :tailwind)
    end

    defp update_aliases(igniter) do
      igniter
      |> TaskAliases.modify_existing_alias(:"assets.setup", &replace_with_empty/1)
      |> TaskAliases.modify_existing_alias(:"assets.build", &replace_with_build/1)
      |> TaskAliases.modify_existing_alias(:"assets.deploy", &replace_with_deploy/1)
    end

    defp replace_with_empty(zipper), do: {:ok, Common.replace_code(zipper, [])}

    defp replace_with_build(zipper) do
      {:ok, Common.replace_code(zipper, ["compile", "volt.build --tailwind"])}
    end

    defp replace_with_deploy(zipper) do
      {:ok, Common.replace_code(zipper, ["volt.build --tailwind", "phx.digest"])}
    end

    # ── Add Volt config ──

    defp add_volt_config(igniter) do
      entry = detect_entry()

      igniter
      |> ProjectConfig.configure("config.exs", :volt, [:entry], entry)
      |> ProjectConfig.configure("config.exs", :volt, [:outdir], "priv/static/assets")
      |> ProjectConfig.configure("config.exs", :volt, [:target], :es2020)
      |> ProjectConfig.configure("config.exs", :volt, [:sourcemap], :hidden)
      |> ProjectConfig.configure(
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

      ProjectConfig.configure(
        igniter,
        "config.exs",
        :volt,
        [:format],
        {:code, Sourceror.parse_string!("[\n  #{code}\n]")}
      )
    end

    defp add_lint_config(igniter) do
      ProjectConfig.configure(
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

    defp add_formatter_plugin(igniter) do
      ProjectFormatter.add_formatter_plugin(igniter, Volt.Formatter)
    end

    defp add_dev_config(igniter, app_name, endpoint) do
      watcher =
        {:code,
         Sourceror.parse_string!("""
         {Mix.Tasks.Volt.Dev, :run, [~w(--tailwind)]}
         """)}

      igniter
      |> ProjectConfig.configure("dev.exs", app_name, [endpoint, :watchers, :volt], watcher)
      |> ProjectConfig.configure("dev.exs", :volt, [:server, :prefix], "/assets")
      |> ProjectConfig.configure(
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
        Igniter.Project.Module.find_and_update_module!(
          igniter,
          endpoint,
          &insert_dev_server_plug(&1, endpoint)
        )
      else
        Igniter.add_warning(igniter, """
        No endpoint found. Please add the Volt dev server plug manually:

          plug Volt.DevServer, root: "assets"
        """)
      end
    end

    defp insert_dev_server_plug(zipper, endpoint) do
      with :error <- Common.move_to(zipper, &has_dev_server_plug?/1),
           {:ok, zipper} <- Common.move_to(zipper, &code_reloading?/1) do
        {:ok,
         Common.add_code(
           zipper,
           """
           plug Volt.DevServer, root: "assets"
           """,
           placement: :after
         )}
      else
        {:ok, _} -> {:ok, zipper}
        :error -> dev_server_warning(endpoint)
      end
    end

    defp has_dev_server_plug?(zipper) do
      Function.function_call?(zipper, :plug) and
        Function.argument_equals?(zipper, 0, Volt.DevServer)
    end

    defp dev_server_warning(endpoint) do
      {:warning,
       """
       Could not find the code_reloading? section in `#{inspect(endpoint)}`.
       Please add the plug manually inside `if code_reloading? do`:

         plug Volt.DevServer, root: "assets"
       """}
    end

    # ── Helpers ──

    defp code_reloading?(zipper) do
      Function.function_call?(zipper, :if, 2) &&
        Function.argument_matches_predicate?(
          zipper,
          0,
          &Common.variable?(&1, :code_reloading?)
        )
    end

    defp detect_entry do
      cond do
        File.exists?("assets/js/app.ts") -> "assets/js/app.ts"
        File.exists?("assets/js/app.js") -> "assets/js/app.js"
        true -> "assets/js/app.ts"
      end
    end

    defp endpoint_module(igniter) do
      app_name =
        igniter
        |> Igniter.Project.Application.app_name()
        |> to_string()
        |> Macro.camelize()

      Module.concat([String.to_atom("#{app_name}Web"), Endpoint])
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
