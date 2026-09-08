defmodule Mix.Tasks.Volt.Js.Check do
  use Mix.Task

  @shortdoc "Lint and format-check Volt TypeScript assets"

  @moduledoc """
  Check formatting and lint Volt's JavaScript and TypeScript assets via NIF.

      mix volt.js.check
      mix volt.js.check --type-aware --type-check

  Reads format options from `config :volt, :format` (falls back to `.oxfmtrc.json`).
  Lint settings come from `config :volt, :lint`.
  File discovery uses `config :volt, sources:` and `ignore:`.

  `--type-aware` runs TypeScript-aware rules through `tsgolint` headless mode.
  Pass `--type-check` to include TypeScript syntactic and semantic diagnostics.
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.config")

    opts = parse_args!(args)
    format_files = Volt.JS.Helpers.discover_format_files()
    lint_files = Volt.JS.Helpers.discover_files(tool: :lint)

    if format_files == [] and lint_files == [] do
      Mix.shell().info("No files found")
    else
      format_ok = check_formatting(format_files)
      lint_ok = check_lint(lint_files, opts)

      unless format_ok and lint_ok do
        exit({:shutdown, 1})
      end
    end
  end

  defp check_formatting([]), do: true

  defp check_formatting(files) do
    case Volt.JS.Check.check_formatting(files) do
      %{errors: [_ | _] = errors} ->
        Mix.shell().error("#{length(errors)} file(s) could not be formatted:")

        Enum.each(errors, fn {file, format_errors} ->
          Mix.shell().error(
            "  #{file}: #{format_errors |> List.wrap() |> Enum.map_join(", ", &Volt.JS.Check.lint_error_message/1)}"
          )
        end)

        false

      %{unformatted: [], total: total} ->
        Mix.shell().info(IO.ANSI.format([:green, "✓ All #{total} files formatted"]))
        true

      %{unformatted: unformatted} ->
        Mix.shell().error("#{length(unformatted)} file(s) need formatting:")
        Enum.each(unformatted, &Mix.shell().error("  #{&1}"))
        false
    end
  end

  defp check_lint([], _opts), do: true

  defp check_lint(files, opts) do
    diags = Volt.JS.Check.lint(files, opts)

    if diags == [] do
      Mix.shell().info(
        IO.ANSI.format([:green, "✓ No lint issues", :reset, :faint, " (#{length(files)} files)"])
      )

      true
    else
      print_lint_diags(diags)
    end
  end

  defp parse_args!(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args,
        strict: [type_aware: :boolean, type_check: :boolean],
        aliases: [T: :type_aware]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{Enum.map_join(invalid, ", ", &elem(&1, 0))}")
    end

    opts
  end

  defp print_lint_diags(diags) do
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
