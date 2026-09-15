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
      %{diagnostic | severity: :deny}
    else
      diagnostic
    end
  end

  def type_check_diagnostic?(rule) do
    rule
    |> to_string()
    |> String.match?(~r/^(typescript\/)?TS\d+$/)
  end

  def lint_error_message(%{message: message}), do: message
  def lint_error_message(message) when is_binary(message), do: message
  def lint_error_message(message), do: inspect(message)

  defp ast_lint(files, config) do
    Enum.flat_map(files, fn file ->
      source = File.read!(file)
      options = Volt.JS.Lint.Config.options(config, file)

      case OXC.Lint.run(source, file, options) do
        {:ok, diagnostics} -> Enum.map(diagnostics, &Map.put(&1, :file, file))
        {:error, errors} -> Enum.map(errors, &lint_error(&1, file))
      end
    end)
  end

  defp type_aware_lint(files, config, lint_config, opts) do
    {files, source_overrides, source_files} = type_aware_inputs(files, config)

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
      |> Keyword.take([:plugins, :rules])
      |> Keyword.update!(:rules, &typescript_rules/1)
    end)
    |> Enum.sort_by(fn {options, _files} -> options end)
    |> Enum.flat_map(fn {options, batch} ->
      case run_type_aware_lint(batch, Keyword.merge(common_opts, options)) do
        {:ok, diagnostics} ->
          Enum.map(diagnostics, fn diagnostic ->
            diagnostic |> restore_sfc_file(source_files) |> promote_type_check_diagnostic(opts)
          end)

        {:error, errors} ->
          Enum.map(errors, &lint_error/1)
      end
    end)
  end

  defp type_aware_inputs(files, config) do
    plugins = Keyword.get(config, :plugins, [])

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
            rules = Map.put(lint_opts[:rules], "typescript/#{rule}", :allow)
            run_type_aware_lint(files, Keyword.put(lint_opts, :rules, rules))
        end

      result ->
        result
    end
  end

  defp unknown_tsgolint_rule(errors) do
    Enum.find_value(errors, fn error ->
      case Regex.run(~r/unknown rule: ([\w-]+)/, lint_error_message(error)) do
        [_, rule] -> rule
        _ -> nil
      end
    end)
  end

  defp typescript_rules(rules) do
    Map.filter(rules, fn {rule, _config} ->
      to_string(rule) in ~w(all correctness suspicious pedantic perf style restriction nursery) or
        String.starts_with?(to_string(rule), "typescript/")
    end)
  end

  defp type_aware_options(config) do
    config
    |> Keyword.take([:tsgolint, :fix, :fix_suggestions, :cwd])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp lint_error(message), do: lint_error(message, "volt.js.check")

  defp lint_error(message, file) do
    %{severity: :deny, file: file, message: lint_error_message(message), rule: "oxc/lint"}
  end
end
