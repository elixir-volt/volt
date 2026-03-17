defmodule Volt.Tailwind do
  @moduledoc """
  Tailwind CSS integration — scan source files for candidates and compile CSS.

  Uses Oxide for fast parallel content scanning and QuickBEAM to run
  the Tailwind CSS compiler. No Node.js or CLI required.

  ## Usage

      # In your config:
      config :volt, :tailwind,
        sources: [
          %{base: "lib/", pattern: "**/*.{ex,heex}"},
          %{base: "assets/", pattern: "**/*.{vue,ts,tsx}"}
        ]

      # Generate CSS:
      {:ok, css} = Volt.Tailwind.build()
  """

  use GenServer

  @bundle_path Path.join(:code.priv_dir(:volt) |> to_string(), "tailwind.js")

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Compile Tailwind CSS from scanned candidates.

  Scans all configured source directories for Tailwind class candidates,
  then runs the Tailwind compiler to generate CSS.

  ## Options

    * `:css` — custom input CSS (default: Tailwind's base with theme + preflight + utilities)
    * `:sources` — override source patterns (default: from config)
    * `:minify` — minify the output CSS (default: `false`)
  """
  @spec build(keyword()) :: {:ok, String.t()} | {:error, term()}
  def build(opts \\ []) do
    GenServer.call(__MODULE__, {:build, opts}, :infinity)
  end

  @doc """
  Incremental build — only process changed files and return CSS if new candidates found.

  Returns `{:ok, css}` if new candidates were found, `:unchanged` otherwise.
  """
  @spec rebuild(list(), keyword()) :: {:ok, String.t()} | :unchanged | {:error, term()}
  def rebuild(changed_files, opts \\ []) do
    GenServer.call(__MODULE__, {:rebuild, changed_files, opts}, :infinity)
  end

  @impl true
  def init(opts) do
    sources = opts[:sources] || Volt.Config.tailwind()[:sources] || []

    {:ok, rt} = QuickBEAM.start()
    {:ok, _} = QuickBEAM.eval(rt, "globalThis.process = {env: {NODE_ENV: 'production'}};")
    {:ok, _} = QuickBEAM.eval(rt, File.read!(@bundle_path))

    scanner =
      if sources != [] do
        oxide_sources = Enum.map(sources, &to_oxide_source/1)
        Oxide.new(sources: oxide_sources)
      end

    {:ok,
     %{
       runtime: rt,
       scanner: scanner,
       sources: sources,
       last_css: nil
     }}
  end

  @impl true
  def handle_call({:build, opts}, _from, state) do
    sources = opts[:sources] || state.sources
    css_input = opts[:css]
    minify = Keyword.get(opts, :minify, false)

    scanner =
      if opts[:sources] do
        oxide_sources = Enum.map(sources, &to_oxide_source/1)
        Oxide.new(sources: oxide_sources)
      else
        state.scanner || Oxide.new(sources: [])
      end

    candidates = Oxide.scan(scanner)

    case compile_css(state.runtime, css_input, candidates) do
      {:ok, css} ->
        css = maybe_minify(css, minify)
        {:reply, {:ok, css}, %{state | scanner: scanner, last_css: css}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:rebuild, changed_files, opts}, _from, state) do
    minify = Keyword.get(opts, :minify, false)
    css_input = opts[:css]

    changed =
      Enum.map(changed_files, fn
        path when is_binary(path) ->
          %Oxide.Changed{file: path, extension: Path.extname(path) |> String.trim_leading(".")}

        map ->
          struct!(Oxide.Changed, map)
      end)

    case state.scanner do
      nil ->
        {:reply, {:error, :no_scanner}, state}

      scanner ->
        new_candidates = Oxide.scan_files(scanner, changed)

        if new_candidates == [] do
          {:reply, :unchanged, state}
        else
          all_candidates = Oxide.scan(scanner)

          case compile_css(state.runtime, css_input, all_candidates) do
            {:ok, css} ->
              css = maybe_minify(css, minify)
              {:reply, {:ok, css}, %{state | last_css: css}}

            {:error, _} = error ->
              {:reply, error, state}
          end
        end
    end
  end

  @impl true
  def terminate(_reason, state) do
    if state.runtime, do: QuickBEAM.stop(state.runtime)
    :ok
  end

  defp compile_css(runtime, nil, candidates) do
    candidates_js = Jason.encode!(candidates)

    case QuickBEAM.eval(runtime, "TW.compileCss(null, #{candidates_js})") do
      {:ok, css} when is_binary(css) -> {:ok, css}
      {:ok, _} -> {:error, :unexpected_result}
      {:error, _} = error -> error
    end
  end

  defp compile_css(runtime, css_input, candidates) do
    candidates_js = Jason.encode!(candidates)
    css_js = Jason.encode!(css_input)

    case QuickBEAM.eval(runtime, "TW.compileCss(#{css_js}, #{candidates_js})") do
      {:ok, css} when is_binary(css) -> {:ok, css}
      {:ok, _} -> {:error, :unexpected_result}
      {:error, _} = error -> error
    end
  end

  defp maybe_minify(css, false), do: css

  defp maybe_minify(css, true) do
    case Vize.compile_css(css, minify: true) do
      {:ok, %{code: minified}} -> minified
      _ -> css
    end
  end

  defp to_oxide_source(%{base: base, pattern: pattern} = source) do
    %Oxide.Source{
      base: Path.expand(base),
      pattern: pattern,
      negated: Map.get(source, :negated, false)
    }
  end
end
