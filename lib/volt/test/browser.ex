defmodule Volt.Test.Browser do
  @moduledoc """
  The browser a test run shares.

  Browsers are launched once per type, the first time a test asks for one,
  and every test gets a browser context of its own, which isolates its
  storage, cookies and pages the way a browser of its own would. See
  `with_page/3`.

  The process also keeps what the contexts load: the test runtime,
  `priv/ts/test/browser.ts`, bundled once when the run starts and installed
  in every context before its page loads, and the bundled test modules,
  written to `_build/volt/browser-tests`, emptied when the run starts, and
  reused while the source files they were bundled from keep their
  modification times. See `module/2`.

  `Volt.Test.Browser.Supervisor` starts this process next to the Playwright
  driver.
  """

  use GenServer

  alias Volt.Test.Browser.Supervisor, as: Tree

  @table __MODULE__

  @type launched :: %{guid: String.t()}

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Open a context in the browser of `type`, with the test runtime installed
  and a page on the blank document, and call `fun` with the page's main frame.

  The context closes when `fun` returns or raises. A browser that is no longer
  reachable, because it crashed since it was launched, is launched again once.
  """
  @spec with_page(atom(), timeout(), (map() -> result)) :: result | {:error, term()}
        when result: term()
  def with_page(type, timeout, fun) do
    with {:ok, browser} <- launch(type, timeout),
         {:ok, context} <- new_context(browser, type, timeout) do
      try do
        with {:ok, _} <- browser_context_add_init_script(context.guid, runtime(), timeout),
             {:ok, %{main_frame: frame}} <- browser_context_new_page(context.guid, timeout),
             {:ok, _} <- frame_goto(frame.guid, page_url(), timeout) do
          fun.(frame)
        end
      after
        browser_context_close(context.guid, timeout)
      end
    end
  end

  defp new_context(browser, type, timeout) do
    case browser_new_context(browser.guid, timeout) do
      {:ok, context} ->
        {:ok, context}

      {:error, _reason} ->
        with :ok <- forget(type, browser.guid),
             {:ok, browser} <- launch(type, timeout) do
          browser_new_context(browser.guid, timeout)
        end
    end
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

  @doc """
  The `file:` URL of the bundled module for the test file at `path`, bundled
  with `bundle_opts`.

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

  defp page_url, do: file_url(Path.join(dir(), "index.html"))
  defp runtime, do: :ets.lookup_element(@table, :runtime, 2)
  defp dir, do: :ets.lookup_element(@table, :dir, 2)

  defp file_url(path) do
    %URI{scheme: "file", path: path} |> URI.to_string()
  end

  @impl true
  def init(_opts) do
    # The VM halts at the end of `mix test` without stopping applications, so
    # the directory is emptied at the start of a run rather than at its end.
    dir = Volt.Paths.expand(Path.join(build_path(), "volt/browser-tests"))

    with {:ok, runtime} <- Volt.Priv.bundle({:volt, "ts"}, "test/browser.ts"),
         {:ok, _removed} <- File.rm_rf(dir),
         :ok <- File.mkdir_p(dir),
         :ok <-
           File.write(Path.join(dir, "index.html"), "<!doctype html><meta charset=\"utf-8\">") do
      # The table appears once the process can serve from it. Callers reach it
      # after `launch/2`, which waits for this initialization.
      :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
      :ets.insert(@table, [{:dir, dir}, {:runtime, runtime}])
      {:ok, %{browsers: %{}}}
    else
      {:error, reason} -> {:stop, {:browser_tests, reason}}
    end
  end

  defp build_path, do: System.get_env("MIX_BUILD_PATH") || "_build"

  @impl true
  def handle_call({:launch, type, timeout}, _from, state) do
    case Map.fetch(state.browsers, type) do
      {:ok, browser} ->
        {:reply, {:ok, browser}, state}

      :error ->
        case launch_browser(type, timeout) do
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

  # The playwright_ex dependency is only present in test environments, so its
  # functions are called without compile-time references.
  defp launch_browser(type, timeout) do
    apply(PlaywrightEx, :launch_browser, [type, [connection: Tree.connection(), timeout: timeout]])
  end

  defp browser_new_context(browser_guid, timeout) do
    apply(PlaywrightEx.Browser, :new_context, [
      browser_guid,
      [connection: Tree.connection(), timeout: timeout]
    ])
  end

  defp browser_context_add_init_script(context_guid, source, timeout) do
    apply(PlaywrightEx.BrowserContext, :add_init_script, [
      context_guid,
      [source: source, connection: Tree.connection(), timeout: timeout]
    ])
  end

  defp browser_context_new_page(context_guid, timeout) do
    apply(PlaywrightEx.BrowserContext, :new_page, [
      context_guid,
      [connection: Tree.connection(), timeout: timeout]
    ])
  end

  defp browser_context_close(context_guid, timeout) do
    apply(PlaywrightEx.BrowserContext, :close, [
      context_guid,
      [connection: Tree.connection(), timeout: timeout]
    ])
  end

  defp frame_goto(frame_guid, url, timeout) do
    apply(PlaywrightEx.Frame, :goto, [
      frame_guid,
      [url: url, connection: Tree.connection(), timeout: timeout]
    ])
  end
end
