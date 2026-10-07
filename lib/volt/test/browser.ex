defmodule Volt.Test.Browser do
  @moduledoc """
  The browser a test run shares.

  Launching a browser costs more than running a test in it, and starting the
  Playwright driver that launches it costs about as much again. Both live here
  for the whole run: the driver under this supervisor and the browsers in
  `Volt.Test.Browser.Run`, launched the first time a test asks for one. Each
  test gets a browser context of its own, which isolates its storage, cookies
  and pages the way a browser of its own would.

  The run also keeps the bundled test modules the browser loads, so a file is
  bundled once for all of its tests. See `module/2`.

  The supervisor is started under `Volt.Supervisor` on first use, with the
  `:playwright` options of the configuration that started it.
  """

  use Supervisor

  alias Volt.Test.Browser.Run
  alias Volt.Test.Config

  @playwright Volt.Test.Browser.Playwright

  @doc "Start the run's browser tree, or find it already running."
  @spec start(Config.t()) :: {:ok, pid()} | {:error, term()}
  def start(%Config{} = config) do
    case Supervisor.start_child(Volt.Supervisor, {__MODULE__, config}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def child_spec(config) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [config]},
      restart: :temporary,
      type: :supervisor
    }
  end

  @doc false
  def start_link(%Config{} = config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(%Config{} = config) do
    # The driver is a port and the browsers are its children, so a driver
    # that went away takes the launched browsers with it.
    children = [
      %{
        id: @playwright,
        start: {PlaywrightEx.Supervisor, :start_link, [playwright_opts(config)]},
        type: :supervisor
      },
      {Run, connection: connection()}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @doc "The Playwright connection the run's browsers belong to."
  @spec connection() :: GenServer.name()
  def connection, do: Module.concat(@playwright, "Connection")

  @doc """
  Open a context in the run's browser of `type`, with the test runtime
  installed and a page on the run's blank document, and call `fun` with the
  page's main frame.

  The context closes when `fun` returns or raises. A browser that is no longer
  reachable, because it crashed since it was launched, is launched again once.
  """
  @spec with_page(atom(), timeout(), (map() -> result)) :: result | {:error, term()}
        when result: term()
  def with_page(type, timeout, fun) do
    with {:ok, browser} <- Run.launch(type, timeout),
         {:ok, context} <- new_context(browser, type, timeout) do
      try do
        with {:ok, _} <- browser_context_add_init_script(context.guid, Run.runtime(), timeout),
             {:ok, %{main_frame: frame}} <- browser_context_new_page(context.guid, timeout),
             {:ok, _} <- frame_goto(frame.guid, Run.page_url(), timeout) do
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
        with :ok <- Run.forget(type, browser.guid),
             {:ok, browser} <- Run.launch(type, timeout) do
          browser_new_context(browser.guid, timeout)
        end
    end
  end

  @doc """
  The `file:` URL of the bundled module for the test file at `path`, bundled
  with `bundle_opts`.

  The bundle is kept for the run and reused while none of its source files
  changed.
  """
  @spec module(Path.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  defdelegate module(path, bundle_opts), to: Run

  defp playwright_opts(%Config{} = config) do
    config.playwright
    |> Keyword.put_new(:timeout, config.timeout)
    |> Keyword.put_new(:executable, playwright_executable())
    |> Keyword.put(:name, @playwright)
  end

  defp playwright_executable do
    local = Path.expand("node_modules/playwright/cli.js", Volt.Paths.root())
    if File.exists?(local), do: local, else: "playwright"
  end

  # The playwright_ex dependency is only present in test environments, so its
  # functions are called without compile-time references.
  defp browser_new_context(browser_guid, timeout) do
    apply(PlaywrightEx.Browser, :new_context, [
      browser_guid,
      [connection: connection(), timeout: timeout]
    ])
  end

  defp browser_context_add_init_script(context_guid, source, timeout) do
    apply(PlaywrightEx.BrowserContext, :add_init_script, [
      context_guid,
      [source: source, connection: connection(), timeout: timeout]
    ])
  end

  defp browser_context_new_page(context_guid, timeout) do
    apply(PlaywrightEx.BrowserContext, :new_page, [
      context_guid,
      [connection: connection(), timeout: timeout]
    ])
  end

  defp browser_context_close(context_guid, timeout) do
    apply(PlaywrightEx.BrowserContext, :close, [
      context_guid,
      [connection: connection(), timeout: timeout]
    ])
  end

  defp frame_goto(frame_guid, url, timeout) do
    apply(PlaywrightEx.Frame, :goto, [
      frame_guid,
      [url: url, connection: connection(), timeout: timeout]
    ])
  end
end
