defmodule Volt.Tailwind.Worker do
  @moduledoc false

  use GenServer

  alias Volt.Tailwind.State

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  @impl true
  def init(opts) do
    {:ok,
     %State{
       key: Keyword.fetch!(opts, :key),
       scanner: nil,
       last_css: nil,
       sources: Keyword.get(opts, :sources, [])
     }}
  end

  @impl true
  def handle_call({:build, opts}, _from, state) do
    sources = opts[:sources] || state.sources
    scanner = build_scanner(sources)

    case compile_css(opts[:css], scan(scanner), opts[:css_base]) do
      {:ok, css} ->
        css = maybe_minify(css, Keyword.get(opts, :minify, false))
        {:reply, {:ok, css}, %{state | scanner: scanner, last_css: css, sources: sources}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:rebuild, changed_files, opts}, _from, state) do
    case state.scanner do
      nil ->
        {:reply, {:error, :no_scanner}, state}

      scanner ->
        rebuild_css(state, scanner, changed_files, opts)
    end
  end

  defp rebuild_css(state, scanner, changed_files, opts) do
    changed = Enum.map(changed_files, &changed_file/1)

    if Oxide.scan_files(scanner, changed) == [] do
      {:reply, :unchanged, state}
    else
      compile_rebuilt_css(state, scanner, opts)
    end
  end

  defp compile_rebuilt_css(state, scanner, opts) do
    case compile_css(opts[:css], Oxide.scan(scanner), opts[:css_base]) do
      {:ok, css} ->
        css = maybe_minify(css, Keyword.get(opts, :minify, false))
        reply = if css == state.last_css, do: :unchanged, else: {:ok, css}
        {:reply, reply, %{state | last_css: css}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  defp build_scanner([]), do: nil
  defp build_scanner(sources), do: Oxide.new(sources: Enum.map(sources, &source/1))
  defp scan(nil), do: []
  defp scan(scanner), do: Oxide.scan(scanner)

  defp source(%{base: base, pattern: pattern} = source) do
    %Oxide.Source{
      base: Path.expand(base),
      pattern: pattern,
      negated: Map.get(source, :negated, false)
    }
  end

  defp changed_file(path) when is_binary(path) do
    %Oxide.Changed{file: path, extension: path |> Path.extname() |> String.trim_leading(".")}
  end

  defp changed_file(map), do: struct!(Oxide.Changed, map)

  defp compile_css(css, candidates, css_base) do
    Volt.Tailwind.Runtime.call(css, candidates, Path.expand(css_base || File.cwd!()))
  end

  defp maybe_minify(css, false), do: css

  defp maybe_minify(css, true) do
    case Vize.CSS.compile(css, minify: true) do
      {:ok, %{code: minified}} -> minified
    end
  end
end
