defmodule Volt.Tailwind.Worker do
  @moduledoc false

  use GenServer

  alias Volt.Tailwind.{State, Runtime}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :name))
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    {:ok,
     %State{
       key: Keyword.fetch!(opts, :key),
       runtime: Keyword.get(opts, :runtime),
       scanner: nil,
       last_css: nil,
       configured_sources: Keyword.get(opts, :sources, []),
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
    sources = Keyword.get(opts, :sources, state.configured_sources)
    compilation = Volt.Tailwind.Compilation.new(opts)
    runtime = state.runtime || Volt.Tailwind.Supervisor.runtime(state.key)
    state = %{state | runtime: runtime}

    with {:ok, context, metadata} <-
           Runtime.prepare_context(compilation.css, compilation.base, runtime) do
      configured = sources
      sources = effective_sources(metadata, configured, compilation.base)
      scanner = build_scanner(sources)

      case finish_build(
             state,
             compilation,
             scanner,
             sources,
             metadata.dependencies,
             context,
             runtime
           ) do
        {:reply, {:ok, css}, updated} ->
          {:reply, {:ok, css}, %{updated | configured_sources: configured}}

        error ->
          error
      end
    else
      {:error, %Volt.Tailwind.CompileError{dependencies: dependencies}} = error ->
        {:reply, error, %{state | dependencies: Enum.uniq(state.dependencies ++ dependencies)}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:rebuild, changed_files, opts}, _from, state) do
    case state.scanner do
      nil when not is_nil(state.compilation) ->
        compilation = Volt.Tailwind.Compilation.update(state.compilation, opts)
        runtime = state.runtime || Volt.Tailwind.Supervisor.runtime(state.key)
        restore_context(state, compilation, runtime)

      nil ->
        {:reply, {:error, :no_scanner}, state}

      scanner ->
        rebuild_css(state, scanner, changed_files, opts)
    end
  end

  defp finish_build(state, compilation, scanner, sources, dependencies, context, runtime) do
    case Runtime.build_context(context, scan(scanner), runtime) do
      {:ok, css} ->
        css = maybe_minify(css, compilation.minify)

        if state.context, do: Runtime.release_context(state.context, runtime)

        {:reply, {:ok, css},
         %{
           state
           | context: context,
             scanner: scanner,
             last_css: css,
             sources: sources,
             compilation: compilation,
             dependencies: dependencies
         }}

      {:error, _reason} = error ->
        Runtime.release_context(context, runtime)
        {:reply, error, state}
    end
  end

  defp rebuild_css(state, scanner, changed_files, opts) do
    changed = Enum.map(changed_files, &changed_file/1)

    new_candidates = Oxide.scan_files(scanner, changed)
    compilation = Volt.Tailwind.Compilation.update(state.compilation, opts)
    stale? = is_nil(state.context) or not Process.alive?(state.context.runtime)

    if new_candidates == [] and not stale? and compilation == state.compilation do
      {:reply, :unchanged, state}
    else
      compile_rebuilt_css(state, scanner, opts)
    end
  end

  defp compile_rebuilt_css(state, scanner, opts) do
    compilation = Volt.Tailwind.Compilation.update(state.compilation, opts)

    runtime = state.runtime || Volt.Tailwind.Supervisor.runtime(state.key)
    candidates = Oxide.scan(scanner)

    result =
      if state.context && compilation == state.compilation do
        Runtime.build_context(state.context, candidates, runtime)
      else
        {:error, :stale_compiler_context}
      end

    case result do
      {:ok, css} ->
        css = maybe_minify(css, compilation.minify)
        reply = if css == state.last_css, do: :unchanged, else: {:ok, css}
        {:reply, reply, %{state | last_css: css, compilation: compilation}}

      {:error, :stale_compiler_context} ->
        restore_context(state, compilation, runtime)

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  defp restore_context(state, compilation, runtime) do
    with {:ok, context, metadata} <-
           Runtime.prepare_context(compilation.css, compilation.base, runtime) do
      sources = effective_sources(metadata, state.configured_sources, compilation.base)
      scanner = build_scanner(sources)

      case Runtime.build_context(context, scan(scanner), runtime) do
        {:ok, css} ->
          css = maybe_minify(css, compilation.minify)
          if state.context, do: Runtime.release_context(state.context, runtime)
          reply = if css == state.last_css, do: :unchanged, else: {:ok, css}

          {:reply, reply,
           %{
             state
             | context: context,
               scanner: scanner,
               sources: sources,
               compilation: compilation,
               last_css: css,
               dependencies: metadata.dependencies
           }}

        {:error, _} = error ->
          Runtime.release_context(context, runtime)
          {:reply, error, state}
      end
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  defp effective_sources(metadata, configured, base) do
    automatic =
      case metadata.root do
        :none -> []
        :automatic -> if configured == [], do: [%{base: base, pattern: "**/*"}], else: []
        source -> [source]
      end

    Enum.uniq(automatic ++ configured ++ metadata.sources)
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

  @impl true
  def terminate(_reason, %{context: nil}), do: :ok

  def terminate(_reason, state) do
    runtime = state.runtime || Volt.Tailwind.Runtime
    if GenServer.whereis(runtime), do: Runtime.release_context(state.context, runtime)
    :ok
  catch
    :exit, _reason -> :ok
  end

  defp maybe_minify(css, false), do: css

  defp maybe_minify(css, true) do
    case Vize.CSS.compile(css, minify: true) do
      {:ok, %{code: minified}} -> minified
    end
  end
end
