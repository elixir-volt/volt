defmodule Volt.Test.Browser.Run do
  @moduledoc """
  What one test run keeps: the browsers it launched, the test runtime and the
  test modules it bundled.

  Browsers are launched once per type, on the first request. The test runtime,
  `priv/ts/test/browser.ts`, is bundled once when the run starts and installed
  in every context before its page loads. Bundled test modules are written to
  `_build/volt/browser-tests`, emptied when the run starts, and are
  reused while the source files they were bundled from keep their
  modification times.
  """

  use GenServer

  @table __MODULE__

  @type launched :: %{guid: String.t()}

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "The browser of `type`, launched on first request."
  @spec launch(atom(), timeout()) :: {:ok, launched()} | {:error, term()}
  def launch(type, timeout) do
    GenServer.call(__MODULE__, {:launch, type, timeout}, :infinity)
  end

  @doc "Drop a browser that is no longer reachable, so the next request launches a new one."
  @spec forget(atom(), String.t()) :: :ok
  def forget(type, guid) do
    GenServer.call(__MODULE__, {:forget, type, guid})
  end

  @doc "The `file:` URL of the blank page tests open."
  @spec page_url() :: String.t()
  def page_url do
    file_url(Path.join(dir(), "index.html"))
  end

  @doc "The test runtime, to install in a context before its page loads."
  @spec runtime() :: String.t()
  def runtime do
    :ets.lookup_element(@table, :runtime, 2)
  end

  @doc """
  The `file:` URL of the bundled module for the test file at `path`.

  Bundling happens in the caller, so tests of different files bundle
  concurrently. Modules are named by their content, so two callers bundling
  the same file at once write the same module.
  """
  @spec module(Path.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def module(path, bundle_opts) do
    key = {Path.expand(path), bundle_opts}

    case :ets.lookup(@table, key) do
      [{^key, %{sources: sources, url: url}}] ->
        if sources == modification_times(sources), do: {:ok, url}, else: bundle(key, bundle_opts)

      [] ->
        bundle(key, bundle_opts)
    end
  end

  defp bundle(key, bundle_opts) do
    with {:ok, bundled} <- Volt.Builder.bundle(bundle_opts),
         {:ok, url} <- write_module(bundled.code) do
      sources = modification_times(Enum.map(bundled.files, &{&1, nil}))
      :ets.insert(@table, {key, %{sources: sources, url: url}})
      {:ok, url}
    end
  end

  defp modification_times(sources) do
    Enum.map(sources, fn {path, _mtime} ->
      case File.stat(path, time: :posix) do
        {:ok, %File.Stat{mtime: mtime}} -> {path, mtime}
        {:error, _reason} -> {path, nil}
      end
    end)
  end

  defp write_module(code) do
    name = Base.url_encode64(:crypto.hash(:sha256, code), padding: false) <> ".mjs"
    path = Path.join(dir(), name)

    if File.regular?(path) do
      {:ok, file_url(path)}
    else
      with :ok <- File.write(path, code), do: {:ok, file_url(path)}
    end
  end

  defp dir do
    :ets.lookup_element(@table, :dir, 2)
  end

  defp file_url(path) do
    %URI{scheme: "file", path: path} |> URI.to_string()
  end

  @impl true
  def init(opts) do
    # The VM halts at the end of `mix test` without stopping applications, so
    # the directory is emptied at the start of a run rather than at its end.
    dir = Volt.Paths.expand(Path.join(build_path(), "volt/browser-tests"))

    with {:ok, runtime} <- Volt.Priv.bundle({:volt, "ts"}, "test/browser.ts"),
         {:ok, _removed} <- File.rm_rf(dir),
         :ok <- File.mkdir_p(dir),
         :ok <-
           File.write(Path.join(dir, "index.html"), "<!doctype html><meta charset=\"utf-8\">") do
      # The table appears once the run can serve from it. Callers reach it
      # after `launch/2`, which waits for this initialization.
      :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
      :ets.insert(@table, [{:dir, dir}, {:runtime, runtime}])
      {:ok, %{connection: Keyword.fetch!(opts, :connection), browsers: %{}}}
    else
      {:error, reason} -> {:stop, {:browser_test_run, reason}}
    end
  end

  @impl true
  def handle_call({:launch, type, timeout}, _from, state) do
    case Map.fetch(state.browsers, type) do
      {:ok, browser} ->
        {:reply, {:ok, browser}, state}

      :error ->
        case launch_browser(type, state.connection, timeout) do
          {:ok, browser} ->
            {:reply, {:ok, browser}, put_in(state.browsers[type], browser)}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:forget, type, guid}, _from, state) do
    case state.browsers do
      %{^type => %{guid: ^guid}} ->
        {:reply, :ok, %{state | browsers: Map.delete(state.browsers, type)}}

      _other ->
        {:reply, :ok, state}
    end
  end

  defp build_path, do: System.get_env("MIX_BUILD_PATH") || "_build"

  # The playwright_ex dependency is only present in test environments, so its
  # functions are called without compile-time references.
  defp launch_browser(type, connection, timeout) do
    apply(PlaywrightEx, :launch_browser, [type, [connection: connection, timeout: timeout]])
  end
end
