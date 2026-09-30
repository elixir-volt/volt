defmodule Volt.Dev.Error do
  @moduledoc """
  JSON-safe error entries for the development error overlay.

  Build errors arrive as `OXC.Diagnostic` maps, compiler messages, exceptions, or
  arbitrary terms. `entries/2` turns any of them into maps the browser overlay
  renders, with a source frame when the file and line are known.
  """

  @type entry :: %{
          message: String.t(),
          file: String.t() | nil,
          line: pos_integer() | nil,
          column: pos_integer() | nil,
          hint: String.t() | nil,
          frame: String.t() | nil
        }

  @doc """
  Build overlay entries from an error `reason`.

  ## Options

    * `:file` — the source path the errors belong to. It names entries that have
      no file or only its basename, and is read for source frames.
  """
  @spec entries(term(), keyword()) :: [entry()]
  def entries(reason, opts \\ [])

  def entries(errors, opts) when is_list(errors), do: Enum.flat_map(errors, &entries(&1, opts))

  def entries(%{__exception__: true} = exception, opts),
    do: [entry(Exception.message(exception), opts, [])]

  def entries(%{message: message} = diagnostic, opts) when is_binary(message) do
    {line, column} = position(diagnostic[:position])
    hint = if is_binary(diagnostic[:details]), do: diagnostic[:details]

    [entry(message, opts, file: diagnostic[:file], line: line, column: column, hint: hint)]
  end

  def entries(message, opts) when is_binary(message), do: [entry(message, opts, [])]
  def entries(reason, opts), do: [entry(inspect(reason), opts, [])]

  defp entry(message, opts, fields) do
    file = source_file(fields[:file], opts[:file])
    line = fields[:line]
    column = fields[:column]

    %{
      message: message,
      file: file && Path.relative_to_cwd(file),
      line: line,
      column: column,
      hint: fields[:hint],
      frame: frame(file, line, column)
    }
  end

  defp source_file(nil, path), do: path
  defp source_file(file, nil), do: file

  defp source_file(file, path) do
    if file == Path.basename(path), do: path, else: file
  end

  defp position({line, column}), do: {line, column}
  defp position(line) when is_integer(line) and line > 0, do: {line, nil}
  defp position(_position), do: {nil, nil}

  defp frame(file, line, column) when is_binary(file) and is_integer(line) do
    with {:ok, source} <- File.read(file),
         lines = String.split(source, ~r/\r?\n/),
         true <- line <= length(lines) do
      first = max(line - 2, 1)
      last = min(line + 1, length(lines))
      width = last |> Integer.to_string() |> byte_size()

      lines
      |> Enum.slice((first - 1)..(last - 1)//1)
      |> Enum.with_index(first)
      |> Enum.flat_map(&frame_rows(&1, line, column, width))
      |> Enum.join("\n")
    else
      _ -> nil
    end
  end

  defp frame(_file, _line, _column), do: nil

  defp frame_rows({text, number}, line, column, width) do
    gutter = number |> Integer.to_string() |> String.pad_leading(width)

    if number == line do
      row = "> #{gutter} | #{text}"

      if column,
        do: [row, "  #{String.duplicate(" ", width)} | #{String.duplicate(" ", column - 1)}^"],
        else: [row]
    else
      ["  #{gutter} | #{text}"]
    end
  end
end
