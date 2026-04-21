defmodule Mix.Tasks.Volt.Js.Check do
  use Mix.Task

  @shortdoc "Lint and format-check Volt TypeScript assets"

  @moduledoc """
  Check formatting and lint Volt's JavaScript and TypeScript assets via NIF.

      mix volt.js.check

  Reads format options from `config :volt, :format` (falls back to `.oxfmtrc.json`).
  Lint settings come from `config :volt, :lint`.
  No Node.js required.
  """

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    dir = Volt.JS.Helpers.assets_dir()
    files = Volt.JS.Helpers.discover_files(dir)

    if files == [] do
      Mix.shell().info("No files found in #{dir}/")
    else
      format_ok = check_formatting(files)
      lint_ok = check_lint(files)

      unless format_ok and lint_ok do
        exit({:shutdown, 1})
      end
    end
  end

  defp check_formatting(files) do
    opts = Volt.JS.Format.load_config()

    unformatted =
      Enum.filter(files, fn file ->
        source = File.read!(file)
        formatted = OXC.Format.run!(source, file, opts)
        formatted != source
      end)

    if unformatted == [] do
      Mix.shell().info(IO.ANSI.format([:green, "✓ All #{length(files)} files formatted"]))
      true
    else
      Mix.shell().error("#{length(unformatted)} file(s) need formatting:")
      Enum.each(unformatted, &Mix.shell().error("  #{&1}"))
      false
    end
  end

  defp check_lint(files) do
    config = Application.get_env(:volt, :lint, [])
    plugins = Keyword.get(config, :plugins, [:typescript])
    rules = Keyword.get(config, :rules, %{})
    custom_rules = Keyword.get(config, :custom_rules, [])

    diags =
      Enum.flat_map(files, fn file ->
        source = File.read!(file)

        case OXC.Lint.run(source, file,
               plugins: plugins,
               rules: rules,
               custom_rules: custom_rules
             ) do
          {:ok, d} -> Enum.map(d, &Map.put(&1, :file, file))
          {:error, _} -> []
        end
      end)

    if diags == [] do
      Mix.shell().info(
        IO.ANSI.format([:green, "✓ No lint issues", :reset, :faint, " (#{length(files)} files)"])
      )

      true
    else
      errors = Enum.count(diags, &(&1.severity == :deny))
      warnings = Enum.count(diags, &(&1.severity == :warn))

      Enum.each(diags, fn diag ->
        tag = if diag.severity == :deny, do: "error", else: "warn"
        Mix.shell().error("  [#{tag}] #{diag.file}: #{diag.message} (#{diag.rule})")
      end)

      Mix.shell().error("#{errors} error(s), #{warnings} warning(s)")
      errors == 0
    end
  end
end
