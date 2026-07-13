defmodule Volt.Test.Shared do
  @moduledoc false

  alias Volt.Test.Config

  def add_source_lines(path, tests) do
    with {:ok, source} <- File.read(path),
         {:ok, lines} <- Volt.Test.Lines.test_lines(source, Path.basename(path)) do
      {:ok,
       tests
       |> Enum.zip(lines)
       |> Enum.map(fn {test, line} -> %{test | line: line} end)}
    else
      {:error, _} -> {:ok, tests}
    end
  end

  def bundle_opts(path, %Config{} = config, opts) do
    setup_files = Enum.map(config.setup_files, &Path.expand(&1, config.root))
    test_plugin = {Volt.Test.Plugin, test_file: Path.expand(path), setup_files: setup_files}
    entry = if setup_files == [], do: path, else: Volt.Test.Plugin.entry_specifier()

    config.bundle
    |> Keyword.merge(Keyword.get(opts, :bundle, []))
    |> Keyword.put(:entry, entry)
    |> Keyword.put_new(:format, :iife)
    |> Keyword.put_new(:minify, false)
    |> Keyword.put_new(:sourcemap, true)
    |> Keyword.put_new(:code_splitting, false)
    |> Keyword.put_new(:mode, "test")
    |> Keyword.update(:plugins, [test_plugin], &[test_plugin | List.wrap(&1)])
  end
end
