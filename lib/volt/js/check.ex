defmodule Volt.JS.Check do
  @moduledoc "Runs JavaScript/TypeScript formatting and lint checks."

  def check_formatting(files, opts \\ Volt.JS.Format.load_config()) do
    Enum.reduce(files, {[], []}, fn file, {unformatted, errors} ->
      source = File.read!(file)

      case OXC.Format.run(source, file, opts) do
        {:ok, ^source} ->
          {unformatted, errors}

        {:ok, _formatted} ->
          {[file | unformatted], errors}

        {:error, format_errors} ->
          {unformatted, [{file, format_errors} | errors]}
      end
    end)
    |> then(fn {unformatted, errors} ->
      %{
        unformatted: Enum.reverse(unformatted),
        errors: Enum.reverse(errors),
        total: length(files)
      }
    end)
  end

  def lint(files, opts \\ []) do
    config = Application.get_env(:volt, :lint, [])
    lint_config = Volt.JS.Lint.Config.new(config, Volt.Config.build().root)

    if opts[:type_aware] do
      ast_lint(Enum.filter(files, &type_aware_file?/1), lint_config) ++
        type_aware_lint(files, config, lint_config, opts)
    else
      ast_lint(files, lint_config)
    end
  end

  def promote_type_check_diagnostic(%{rule: rule} = diagnostic, opts) do
    if Keyword.get(opts, :type_check, false) and type_check_diagnostic?(rule) do
      %{diagnostic | severity: :error}
    else
      diagnostic
    end
  end

  @doc "Formats a diagnostic's location as `file:line:column`, `file`, or `nil` without a file."
  @spec location(OXC.Diagnostic.t()) :: String.t() | nil
  def location(%{file: nil}), do: nil
  def location(%{file: file, position: {line, column}}), do: "#{file}:#{line}:#{column}"
  def location(%{file: file}), do: file

  def type_check_diagnostic?(rule) do
    rule
    |> to_string()
    |> String.match?(~r/^(typescript\/)?TS\d+$/)
  end

  defp ast_lint(files, config) do
    Enum.flat_map(files, fn file ->
      source = File.read!(file)
      options = Volt.JS.Lint.Config.options(config, file)

      case OXC.Lint.run(source, file, options) do
        {:ok, diagnostics} -> diagnostics
        {:error, errors} -> errors
      end
    end)
  end

  defp type_aware_lint(files, config, lint_config, opts) do
    {files, source_overrides, source_files} = type_aware_inputs(files)

    common_opts =
      [
        type_aware: true,
        type_check: opts[:type_check] == true,
        source_overrides: Map.merge(source_overrides, Keyword.get(config, :source_overrides, %{}))
      ] ++ type_aware_options(config)

    files
    |> Enum.group_by(fn file ->
      original = Map.get(source_files, Path.expand(file), file)

      lint_config
      |> Volt.JS.Lint.Config.options(original)
      |> Keyword.fetch!(:rules)
      |> typescript_rules()
    end)
    |> Enum.sort_by(fn {rules, _files} -> rules end)
    |> Enum.flat_map(fn {rules, batch} ->
      case run_type_aware_lint(batch, Keyword.put(common_opts, :rules, rules)) do
        {:ok, diagnostics} ->
          Enum.map(diagnostics, fn diagnostic ->
            diagnostic |> restore_sfc_file(source_files) |> promote_type_check_diagnostic(opts)
          end)

        {:error, errors} ->
          errors
      end
    end)
  end

  defp type_aware_inputs(files) do
    plugins = Volt.Config.build().plugins

    Enum.reduce(files, {[], %{}, %{}}, fn file, {files, overrides, source_files} ->
      if type_aware_file?(file) do
        {[file | files], overrides, source_files}
      else
        file
        |> embedded_modules(plugins)
        |> Enum.reduce({files, overrides, source_files}, fn module, acc ->
          add_embedded_module(acc, file, module)
        end)
      end
    end)
    |> then(fn {files, overrides, source_files} ->
      {Enum.reverse(files), overrides, source_files}
    end)
  end

  defp type_aware_file?(file), do: Path.extname(file) in Volt.JS.Extensions.bundleable()

  defp embedded_modules(file, plugins) do
    Volt.PluginRunner.embedded_modules(plugins, file, File.read!(file), [])
  end

  defp add_embedded_module({files, overrides, source_files}, file, module) do
    virtual_file = "#{file}.#{module.type}#{module.index}#{module.extension}"
    expanded = Path.expand(virtual_file)

    {
      [virtual_file | files],
      Map.put(overrides, expanded, module.source),
      Map.put(source_files, expanded, file)
    }
  end

  defp restore_sfc_file(diagnostic, source_files) do
    case Map.fetch(source_files, diagnostic.file) do
      {:ok, file} -> %{diagnostic | file: file}
      :error -> diagnostic
    end
  end

  defp run_type_aware_lint(files, lint_opts) do
    if map_size(Keyword.fetch!(lint_opts, :rules)) == 0 and not lint_opts[:type_check] do
      {:ok, []}
    else
      do_run_type_aware_lint(files, lint_opts)
    end
  end

  defp do_run_type_aware_lint(files, lint_opts) do
    case OXC.Lint.run(files, lint_opts) do
      {:error, errors} ->
        case unknown_tsgolint_rule(errors) do
          nil ->
            {:error, errors}

          rule ->
            rules = Map.delete(lint_opts[:rules], "typescript/#{rule}")
            run_type_aware_lint(files, Keyword.put(lint_opts, :rules, rules))
        end

      result ->
        result
    end
  end

  defp unknown_tsgolint_rule(errors) do
    Enum.find_value(errors, fn error ->
      case Regex.run(~r/unknown rule: ([\w-]+)/, error.message) do
        [_, rule] -> rule
        _ -> nil
      end
    end)
  end

  defp typescript_rules(rules) do
    Map.filter(rules, fn {rule, _config} ->
      String.starts_with?(to_string(rule), "typescript/")
    end)
  end

  defp type_aware_options(config) do
    config
    |> Keyword.take([:tsgolint, :fix, :fix_suggestions, :cwd])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end
end
