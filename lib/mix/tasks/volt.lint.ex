defmodule Mix.Tasks.Volt.Lint do
  @shortdoc "Lint JavaScript/TypeScript assets with oxlint"

  @moduledoc """
  Lint project JavaScript and TypeScript assets using oxlint via NIF.

      mix volt.lint

  Scans all `.js`, `.ts`, `.jsx`, `.tsx` files under the configured
  `:root` directory (default: `assets/`).

  ## Options

    * `--plugin` — enable an oxlint plugin (repeatable).
      Available: `react`, `typescript`, `unicorn`, `import`, `jsdoc`,
      `jest`, `vitest`, `jsx_a11y`, `nextjs`, `react_perf`, `promise`,
      `node`, `vue`, `oxc`

    * `--fix` — show fix suggestions in output

  ## Configuration

  Configure lint settings in `config :volt, :lint`:

      config :volt, :lint,
        plugins: [:typescript, :react],
        rules: %{
          "no-console" => :warn,
          "eqeqeq" => :deny,
          "typescript/no-explicit-any" => :warn
        },
        custom_rules: [
          {MyApp.NoConsoleLog, :warn}
        ]
  """
  use Mix.Task

  @extensions ~w(.js .ts .jsx .tsx .vue)

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [plugin: [:string, :keep], fix: :boolean],
        aliases: [p: :plugin]
      )

    config = Application.get_env(:volt, :lint, [])
    volt_config = Volt.Config.build()
    root = volt_config.root

    plugins =
      case Keyword.get_values(parsed, :plugin) do
        [] -> Keyword.get(config, :plugins, [:typescript])
        cli_plugins -> Enum.map(cli_plugins, &String.to_atom/1)
      end

    rules = Keyword.get(config, :rules, %{})
    custom_rules = Keyword.get(config, :custom_rules, [])
    fix = Keyword.get(parsed, :fix, false)

    files = discover_files(root)

    if files == [] do
      Mix.shell().info("No lintable files found in #{root}/")
      :ok
    end

    {total_errors, total_warnings} =
      Enum.reduce(files, {0, 0}, fn file, {errors, warnings} ->
        source = File.read!(file)

        case OXC.Lint.run(source, file,
               plugins: plugins,
               rules: rules,
               custom_rules: custom_rules,
               fix: fix
             ) do
          {:ok, []} ->
            {errors, warnings}

          {:ok, diags} ->
            print_diagnostics(file, source, diags)

            file_errors = Enum.count(diags, &(&1.severity == :deny))
            file_warnings = Enum.count(diags, &(&1.severity == :warn))
            {errors + file_errors, warnings + file_warnings}

          {:error, parse_errors} ->
            Mix.shell().error("#{file}: parse error")

            for msg <- parse_errors do
              Mix.shell().error("  #{msg}")
            end

            {errors + 1, warnings}
        end
      end)

    total = total_errors + total_warnings

    if total > 0 do
      summary =
        [
          "#{total} problem#{if total != 1, do: "s"}",
          if(total_errors > 0, do: "#{total_errors} error#{if total_errors != 1, do: "s"}"),
          if(total_warnings > 0,
            do: "#{total_warnings} warning#{if total_warnings != 1, do: "s"}"
          )
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(", ")

      Mix.shell().info("\n#{summary}")
    else
      Mix.shell().info("No lint issues found in #{length(files)} files")
    end

    if total_errors > 0, do: exit({:shutdown, 1})
  end

  defp discover_files(root) do
    Path.wildcard("#{root}/**/*")
    |> Enum.filter(fn path ->
      Path.extname(path) in @extensions and not String.contains?(path, "node_modules")
    end)
    |> Enum.sort()
  end

  defp print_diagnostics(file, source, diags) do
    for diag <- diags do
      {line, col} = offset_to_line_col(source, elem(diag.span, 0))
      severity_label = if diag.severity == :deny, do: "error", else: "warning"

      Mix.shell().info("#{file}:#{line}:#{col} #{severity_label} #{diag.message} [#{diag.rule}]")

      if diag.help do
        Mix.shell().info("  help: #{diag.help}")
      end
    end
  end

  defp offset_to_line_col(source, offset) do
    prefix = binary_part(source, 0, min(offset, byte_size(source)))
    lines = String.split(prefix, "\n")
    line = length(lines)
    col = (List.last(lines) || "") |> String.length() |> Kernel.+(1)
    {line, col}
  end
end
