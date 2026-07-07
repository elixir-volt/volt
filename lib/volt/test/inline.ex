defmodule Volt.Test.Inline do
  @moduledoc "Runs inline JavaScript and TypeScript snippets as Volt tests."

  import ExUnit.Assertions, only: [flunk: 1]

  @spec assert!(String.t(), keyword(), map()) :: :ok
  def assert!(source, opts, caller) when is_binary(source) and is_list(opts) do
    config = Volt.Test.Config.read(opts)
    runner = if config.browser, do: Volt.Test.BrowserRunner, else: Volt.Test.Runner

    case write_test(source, opts, caller) do
      {:ok, path, cleanup} ->
        try do
          case runner.run_file(path, config: config) do
            {:ok, result} ->
              result
              |> Map.put(:file, "#{caller.file}:#{caller.line}")
              |> Volt.Test.Assertions.assert_passed!()

            {:error, reason} ->
              flunk("Volt JS assertion failed to run: #{inspect(reason)}")
          end
        after
          cleanup.()
        end

      {:error, reason} ->
        flunk("Volt JS assertion failed to run: #{inspect(reason)}")
    end
  end

  defp write_test(source, opts, caller) do
    dir = Path.join(System.tmp_dir!(), "volt-inline-test-#{System.unique_integer([:positive])}")
    extension = opts |> Keyword.get(:extension, ".ts") |> normalize_extension()
    path = Path.join(dir, "assertion#{extension}")

    with :ok <- File.mkdir_p(dir),
         {:ok, code} <- test_source(source, Path.basename(path)),
         :ok <- File.write(path, code) do
      {:ok, path, fn -> File.rm_rf(dir) end}
    else
      {:error, reason} -> {:error, {caller.file, caller.line, reason}}
    end
  end

  defp normalize_extension(extension) when is_binary(extension) do
    if String.starts_with?(extension, "."), do: extension, else: "." <> extension
  end

  defp normalize_extension(extension) when is_atom(extension),
    do: extension |> Atom.to_string() |> normalize_extension()

  defp test_source(source, filename) do
    with {:ok, ast} <- OXC.parse(source, filename) do
      ranges = import_ranges(ast)
      imports = extract_ranges(source, ranges)
      body = remove_ranges(source, ranges) |> String.trim()

      {:ok,
       [
         imports,
         if(imports == "", do: "", else: "\n\n"),
         "test('inline assertion', async () => {\n",
         body,
         "\n})\n"
       ]
       |> IO.iodata_to_binary()}
    end
  end

  defp import_ranges(%{body: body}) when is_list(body) do
    body
    |> Enum.filter(&match?(%{type: :import_declaration}, &1))
    |> Enum.map(&{&1.start, &1.end})
  end

  defp import_ranges(_ast), do: []

  defp extract_ranges(source, ranges) do
    Enum.map_join(ranges, "\n", fn {start_pos, end_pos} ->
      binary_part(source, start_pos, end_pos - start_pos)
    end)
  end

  defp remove_ranges(source, ranges) do
    {parts, position} =
      ranges
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.reduce({[], 0}, fn {start_pos, end_pos}, {parts, position} ->
        part = binary_part(source, position, start_pos - position)
        {[part | parts], end_pos}
      end)

    tail = binary_part(source, position, byte_size(source) - position)
    IO.iodata_to_binary(Enum.reverse([tail | parts]))
  end
end
