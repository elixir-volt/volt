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
    rules = Keyword.get(config, :rules, %{})

    if opts[:type_aware] do
      type_aware_lint(files, config, type_aware_rules(rules), opts)
    else
      ast_lint(files, config, rules)
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

  defp ast_lint(files, config, rules) do
    plugins = Keyword.get(config, :plugins, [:typescript])
    custom_rules = Keyword.get(config, :custom_rules, [])

    Enum.flat_map(files, fn file ->
      source = File.read!(file)

      case OXC.Lint.run(source, file,
             plugins: plugins,
             rules: rules,
             custom_rules: custom_rules
           ) do
        {:ok, diagnostics} -> Enum.map(diagnostics, &Map.put(&1, :file, file))
        {:error, errors} -> Enum.map(errors, &lint_error(&1, file))
      end
    end)
  end

  defp type_aware_lint(files, config, rules, opts) do
    {files, source_overrides, source_files} = type_aware_inputs(files, config)

    lint_opts =
      [
        type_aware: true,
        type_check: opts[:type_check] == true,
        rules: rules,
        source_overrides: Map.merge(source_overrides, Keyword.get(config, :source_overrides, %{}))
      ] ++ type_aware_options(config)

    case OXC.Lint.run(files, lint_opts) do
      {:ok, diagnostics} ->
        Enum.map(diagnostics, fn diagnostic ->
          diagnostic
          |> restore_sfc_file(source_files)
          |> promote_type_check_diagnostic(opts)
        end)

      {:error, errors} ->
        Enum.map(errors, &lint_error/1)
    end
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

  defp type_aware_rules(rules) do
    Map.filter(rules, fn {rule, _config} ->
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
