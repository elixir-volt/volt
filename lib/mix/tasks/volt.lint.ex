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

  @category_colors [
    correctness: :yellow,
    typescript: :blue,
    react: :cyan,
    unicorn: :magenta,
    import: :green,
    style: :olive,
    custom: :light_magenta
  ]

  @category_titles [
    correctness: "Correctness",
    typescript: "TypeScript",
    react: "React",
    unicorn: "Unicorn",
    import: "Imports",
    style: "Style",
    custom: "Custom Rules"
  ]

  @category_order [:correctness, :typescript, :react, :unicorn, :import, :style, :custom]

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [plugin: [:string, :keep], fix: :boolean],
        aliases: [p: :plugin]
      )

    config = Application.get_env(:volt, :lint, [])

    plugins =
      case Keyword.get_values(parsed, :plugin) do
        [] -> Keyword.get(config, :plugins, [:typescript])
        cli_plugins -> Enum.map(cli_plugins, &String.to_atom/1)
      end

    rules = Keyword.get(config, :rules, %{})
    custom_rules = Keyword.get(config, :custom_rules, [])
    fix = Keyword.get(parsed, :fix, false)

    files = Volt.JS.Helpers.discover_files(only: ~w(.js .ts .jsx .tsx))

    if files == [] do
      Mix.shell().info("No lintable files found")
      :ok
    else
      results = lint_files(files, plugins, rules, custom_rules, fix)
      print_results(results, files)
    end
  end

  defp lint_files(files, plugins, rules, custom_rules, fix) do
    Enum.flat_map(files, fn file ->
      source = File.read!(file)

      case OXC.Lint.run(source, file,
             plugins: plugins,
             rules: rules,
             custom_rules: custom_rules,
             fix: fix
           ) do
        {:ok, diags} ->
          Enum.map(diags, &Map.put(&1, :file, file))

        {:error, parse_errors} ->
          Enum.map(parse_errors, fn msg ->
            %{
              file: file,
              rule: "parse-error",
              message: msg,
              severity: :deny,
              span: {0, 0},
              labels: [],
              help: nil
            }
          end)
      end
    end)
  end

  defp print_results([], files) do
    Mix.shell().info(
      IO.ANSI.format([:green, "✓ No issues found", :reset, :faint, " (#{length(files)} files)"])
    )
  end

  defp print_results(results, files) do
    term_width = term_columns()

    results
    |> Enum.group_by(&categorize/1)
    |> sort_categories()
    |> Enum.each(fn {category, diags} ->
      print_category(category, diags, term_width)
    end)

    print_summary(results, files)
  end

  defp print_category(category, diags, term_width) do
    color = @category_colors[category] || :white
    title = @category_titles[category] || "#{category}"

    Mix.shell().info("")

    Mix.shell().info(
      IO.ANSI.format([
        :bright,
        color,
        "  ",
        :normal,
        color,
        " #{title}" |> String.pad_trailing(term_width - 3)
      ])
    )

    Mix.shell().info(IO.ANSI.format([color, "┃ "]))

    Enum.each(diags, fn diag ->
      print_diagnostic(diag, color)
    end)
  end

  defp print_diagnostic(diag, edge_color) do
    tag = severity_tag(diag.severity)
    arrow = priority_arrow(diag.severity)
    source = File.read!(diag.file)
    {line, col} = offset_to_line_col(source, elem(diag.span, 0))

    Mix.shell().info(
      IO.ANSI.format([
        edge_color,
        "┃ ",
        :reset,
        edge_color,
        :faint,
        tag,
        " ",
        arrow,
        :reset,
        " ",
        diag.message
      ])
    )

    Mix.shell().info(
      IO.ANSI.format([
        edge_color,
        "┃       ",
        :reset,
        :faint,
        diag.file,
        :default_color,
        :faint,
        ":#{line}:#{col}",
        " #(",
        diag.rule,
        ")"
      ])
    )
  end

  defp print_summary(results, files) do
    errors = Enum.count(results, &(&1.severity == :deny))
    warnings = Enum.count(results, &(&1.severity == :warn))

    by_category =
      results
      |> Enum.group_by(&categorize/1)
      |> Enum.map(fn {cat, diags} ->
        title = @category_titles[cat] || "#{cat}"
        count = length(diags)
        "#{count} #{String.downcase(title)} issue#{pl(count)}"
      end)

    Mix.shell().info("")

    Mix.shell().info(
      IO.ANSI.format([
        :faint,
        "Analysis found ",
        :reset,
        if(errors > 0, do: [:red, "#{errors} error#{pl(errors)}"], else: []),
        if(errors > 0 and warnings > 0, do: [:reset, :faint, ", "], else: []),
        if(warnings > 0, do: [:yellow, "#{warnings} warning#{pl(warnings)}"], else: []),
        :reset,
        :faint,
        " (#{by_category |> Enum.join(", ")})"
      ])
    )

    Mix.shell().info(IO.ANSI.format([:faint, "#{length(files)} files checked"]))

    if errors > 0, do: exit({:shutdown, 1})
  end

  defp categorize(%{rule: rule}) when is_binary(rule) do
    cond do
      rule =~ "custom/" -> :custom
      rule =~ "typescript" -> :typescript
      rule =~ "react" -> :react
      rule =~ "unicorn" -> :unicorn
      rule =~ "import" -> :import
      true -> :correctness
    end
  end

  defp categorize(_), do: :correctness

  defp sort_categories(grouped) do
    Enum.sort_by(grouped, fn {cat, _} ->
      Enum.find_index(@category_order, &(&1 == cat)) || 99
    end)
  end

  defp severity_tag(:deny), do: "[E]"
  defp severity_tag(:warn), do: "[W]"
  defp severity_tag(_), do: "[I]"

  defp priority_arrow(:deny), do: "↗"
  defp priority_arrow(:warn), do: "→"
  defp priority_arrow(_), do: "→"

  defp pl(1), do: ""
  defp pl(_), do: "s"

  defp offset_to_line_col(source, offset) do
    prefix = binary_part(source, 0, min(offset, byte_size(source)))
    lines = String.split(prefix, "\n")
    line = length(lines)
    col = (List.last(lines) || "") |> String.length() |> Kernel.+(1)
    {line, col}
  end

  defp term_columns do
    case :io.columns() do
      {:ok, cols} -> cols
      _ -> 80
    end
  end
end
