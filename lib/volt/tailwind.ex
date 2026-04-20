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

  ## Tailwind directives

  Volt supports Tailwind's CSS-first directives like `@theme`, `@source`,
  `@utility`, `@variant`, and `@apply` through the Tailwind compiler.

  Volt also resolves local `@import`, `@reference`, `@plugin`, and `@config`
  files inside QuickBEAM, plus installed package plugins like
  `@tailwindcss/typography`.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Compile Tailwind CSS from scanned candidates.

  Scans all configured source directories for Tailwind class candidates,
  then runs the Tailwind compiler to generate CSS.

  ## Options

    * `:css` — custom input CSS (default: Tailwind's base with theme + preflight + utilities)
    * `:css_base` — base directory for resolving local `@import`, `@reference`, `@plugin`, and `@config` paths
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

    {:ok,
     %{
       runtime: nil,
       scanner: nil,
       sources: sources,
       last_css: nil
     }}
  end

  defp ensure_runtime(%{runtime: nil} = state) do
    {:ok, rt} =
      QuickBEAM.start(
        apis: [:browser, :node],
        handlers: Volt.Tailwind.Loader.handlers(),
        define: %{
          "TAILWIND_ROOT" => Volt.Tailwind.Loader.ensure_runtime_root!(),
          "TAILWIND_DEFAULT_BASE" => File.cwd!()
        },
        script: Volt.JS.Asset.path_for("tailwind-runtime.ts")
      )

    %{state | runtime: rt, scanner: build_scanner(state.sources)}
  end

  defp ensure_runtime(state), do: state

  @impl true
  def handle_call({:build, opts}, _from, state) do
    state = ensure_runtime(state)
    css_input = opts[:css]
    minify = Keyword.get(opts, :minify, false)
    css_base = opts[:css_base] || File.cwd!()
    sources = opts[:sources] || state.sources

    scanner =
      if(opts[:sources],
        do: build_scanner(sources),
        else: state.scanner || Oxide.new(sources: [])
      )

    case compile_css(state.runtime, css_input, Oxide.scan(scanner), css_base) do
      {:ok, css} ->
        css = maybe_minify(css, minify)
        {:reply, {:ok, css}, %{state | scanner: scanner, last_css: css}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:rebuild, changed_files, opts}, _from, state) do
    state = ensure_runtime(state)
    minify = Keyword.get(opts, :minify, false)
    css_input = opts[:css]
    css_base = opts[:css_base] || File.cwd!()

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
        if Oxide.scan_files(scanner, changed) == [] do
          {:reply, :unchanged, state}
        else
          case compile_css(state.runtime, css_input, Oxide.scan(scanner), css_base) do
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
  def terminate(_reason, %{runtime: nil}), do: :ok

  def terminate(_reason, %{runtime: rt}) do
    QuickBEAM.stop(rt)
    :ok
  end

  defp build_scanner([]), do: nil

  defp build_scanner(sources) do
    oxide_sources = Enum.map(sources, &to_oxide_source/1)
    Oxide.new(sources: oxide_sources)
  end

  defp compile_css(runtime, css_input, candidates, css_base) do
    case QuickBEAM.call(runtime, "compileTailwindCss", [
           css_input,
           candidates,
           Path.expand(css_base)
         ]) do
      {:ok, css} when is_binary(css) -> {:ok, css}
      {:ok, _} -> {:error, :unexpected_result}
      {:error, _} = error -> error
    end
  end

  defp maybe_minify(css, false), do: css

  defp maybe_minify(css, true) do
    {:ok, %{code: minified}} = Vize.compile_css(css, minify: true)
    minified
  end

  defp to_oxide_source(%{base: base, pattern: pattern} = source) do
    %Oxide.Source{
      base: Path.expand(base),
      pattern: pattern,
      negated: Map.get(source, :negated, false)
    }
  end
end
