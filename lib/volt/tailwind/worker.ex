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
       runtime: Keyword.get(opts, :runtime),
       scanner: nil,
       last_css: nil,
       sources: Keyword.get(opts, :sources, [])
     }}
  end

  @doc "Return the last successfully compiled stylesheet without compiling."
  def stylesheet(server), do: GenServer.call(server, :stylesheet)

  def inputs(server), do: GenServer.call(server, :inputs)

  @impl true
  def handle_call(:inputs, _from, state),
    do: {:reply, %{sources: state.sources, dependencies: state.dependencies}, state}

  def handle_call(:stylesheet, _from, state) do
    result = if is_binary(state.last_css), do: {:ok, state.last_css}, else: {:error, :not_built}
    {:reply, result, state}
  end

  def handle_call({:build, opts}, _from, state) do
    sources = opts[:sources] || state.sources
    compilation = Volt.Tailwind.Compilation.new(opts)
    runtime = state.runtime || Volt.Tailwind.Supervisor.runtime(state.key)

    with {:ok, metadata} <-
           Volt.Tailwind.Runtime.compile_metadata(compilation.css, [], compilation.base, runtime) do
      automatic =
        case metadata.root do
          :none ->
            []

          :automatic ->
            if sources == [], do: [%{base: compilation.base, pattern: "**/*"}], else: []

          source ->
            [source]
        end

      sources = Enum.uniq(automatic ++ sources ++ metadata.sources)
      scanner = build_scanner(sources)
      finish_build(state, compilation, scanner, sources, metadata.dependencies)
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  defp finish_build(state, compilation, scanner, sources, dependencies) do
    case compile_css(compilation.css, scan(scanner), compilation.base, state) do
      {:ok, css} ->
        css = maybe_minify(css, compilation.minify)

        {:reply, {:ok, css},
         %{
           state
           | scanner: scanner,
             last_css: css,
             sources: sources,
             compilation: compilation,
             dependencies: dependencies
         }}

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
    compilation = Volt.Tailwind.Compilation.update(state.compilation, opts)

    case compile_css(compilation.css, Oxide.scan(scanner), compilation.base, state) do
      {:ok, css} ->
        css = maybe_minify(css, compilation.minify)
        reply = if css == state.last_css, do: :unchanged, else: {:ok, css}
        {:reply, reply, %{state | last_css: css, compilation: compilation}}

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

  defp compile_css(css, candidates, css_base, state) do
    runtime = state.runtime || Volt.Tailwind.Supervisor.runtime(state.key)
    Volt.Tailwind.Runtime.call(css, candidates, css_base, runtime)
  end

  defp maybe_minify(css, false), do: css

  defp maybe_minify(css, true) do
    case Vize.CSS.compile(css, minify: true) do
      {:ok, %{code: minified}} -> minified
    end
  end
end
