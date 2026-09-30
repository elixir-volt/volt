defmodule Volt.Dev.Error do
  @moduledoc """
  JSON-safe error entries for the development error overlay.

  Build errors arrive as `OXC.Diagnostic` maps, compiler messages, exceptions, or
  arbitrary terms. `entries/2` turns any of them into maps the browser overlay
  renders, with a source frame when the file and line are known.

  With the optional `:lumis` dependency and a Lumis parser package for the file's
  language, such as `:lumis_wasm_typescript`, entries also carry `frame_html`, the
  frame with syntax highlighting.
  """

  @theme "github_dark"

  @type entry :: %{
          message: String.t(),
          file: String.t() | nil,
          line: pos_integer() | nil,
          column: pos_integer() | nil,
          hint: String.t() | nil,
          frame: String.t() | nil,
          frame_html: String.t() | nil
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
    {frame, frame_html} = frames(file, line, column)

    %{
      message: message,
      file: file && Path.relative_to_cwd(file),
      line: line,
      column: column,
      hint: fields[:hint],
      frame: frame,
      frame_html: frame_html
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

  defp frames(file, line, column) when is_binary(file) and is_integer(line) do
    with {:ok, source} <- File.read(file),
         lines = String.split(source, ~r/\r?\n/),
         true <- line <= length(lines) do
      first = max(line - 2, 1)
      last = min(line + 1, length(lines))
      width = last |> Integer.to_string() |> byte_size()
      frame = %{first: first, line: line, column: column, width: width}
      texts = Enum.slice(lines, (first - 1)..(last - 1)//1)

      html =
        with [_ | _] = highlighted <- highlight(file, source, first..last//1) do
          # Lumis leaves out a trailing empty line.
          highlighted = highlighted ++ List.duplicate("", length(texts) - length(highlighted))
          render(frame, highlighted, &html_gutter/1)
        end

      {render(frame, texts, & &1), html}
    else
      _ -> {nil, nil}
    end
  end

  defp frames(_file, _line, _column), do: {nil, nil}

  defp render(frame, texts, gutter) do
    texts
    |> Enum.with_index(frame.first)
    |> Enum.flat_map(fn {text, number} ->
      marker = if number == frame.line, do: ">", else: " "
      padded = number |> Integer.to_string() |> String.pad_leading(frame.width)
      row = gutter.("#{marker} #{padded} | ") <> text

      if number == frame.line and frame.column do
        blank = String.duplicate(" ", frame.width)
        [row, gutter.("  #{blank} | #{String.duplicate(" ", frame.column - 1)}^")]
      else
        [row]
      end
    end)
    |> Enum.join("\n")
  end

  # The error line's marker and caret stand out; other gutters are dim.
  defp html_gutter(gutter) do
    color = if String.contains?(gutter, [">", "^"]), do: "#ff6b9a", else: "#6b5b8f"
    ~s(<span style="color:#{color}">#{String.replace(gutter, ">", "&gt;")}</span>)
  end

  if Code.ensure_loaded?(Lumis) do
    # Highlights the whole file, so tokens that span lines keep their colors, and
    # keeps the lines in `range`. Nil when no Lumis parser covers the language.
    defp highlight(file, source, range) do
      language = Lumis.Languages.guess(file, source)
      formatter = {:html_inline, language: language, theme: @theme}

      with true <- language != "plaintext",
           :ok <- Lumis.Languages.load(language),
           {:ok, html} <- Lumis.highlight(source, formatter: formatter) do
        html
        |> String.split("\n")
        |> Enum.slice((range.first - 1)..(range.last - 1)//1)
        |> Enum.map(&line_html/1)
      else
        _ -> nil
      end
    end

    defp line_html(line) do
      case Regex.run(~r{<span class="l-line"[^>]*>(.*)</span>}, line, capture: :all_but_first) do
        [html] -> html
        nil -> ""
      end
    end
  else
    defp highlight(_file, _source, _range), do: nil
  end
end
