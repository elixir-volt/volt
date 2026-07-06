defmodule Volt.Test.BrowserRunner do
  @moduledoc """
  Executes Volt JavaScript and TypeScript tests inside a real browser via PlaywrightEx.

  This runner is intentionally small and mirrors `Volt.Test.Runner`'s result
  contract so ExUnit integration can switch between QuickBEAM and browser
  execution without changing assertions or reporting.
  """

  alias PlaywrightEx.{Browser, BrowserContext, Frame}
  alias Volt.Test.Config

  @type result :: map()

  @spec collect_file(Path.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def collect_file(path, opts \\ []) do
    with {:ok, tests} <- call_browser_runtime(path, :collect, nil, opts) do
      add_source_lines(path, tests)
    end
  end

  @spec run_file(Path.t(), keyword()) :: {:ok, result()} | {:error, term()}
  def run_file(path, opts \\ []) do
    call_browser_runtime(path, :run, nil, opts)
  end

  @spec run_test(Path.t(), integer(), keyword()) :: {:ok, result()} | {:error, term()}
  def run_test(path, test_id, opts \\ []) when is_integer(test_id) do
    call_browser_runtime(path, :run, test_id, opts)
  end

  defp add_source_lines(path, tests) do
    with {:ok, source} <- File.read(path),
         {:ok, lines} <- Volt.Test.Lines.test_lines(source, Path.basename(path)) do
      {:ok,
       tests
       |> Enum.zip(lines)
       |> Enum.map(fn {test, line} -> Map.put(test, "line", line) end)}
    else
      {:error, _} -> {:ok, tests}
    end
  end

  defp call_browser_runtime(path, mode, test_id, opts) do
    config = Keyword.fetch!(opts, :config)
    timeout = Keyword.get(opts, :timeout, config.timeout)

    with {:ok, bundled} <-
           Volt.Test.Bundler.bundle_file(path, Keyword.get(opts, :compile_opts, [])),
         {:ok, runtime_code} <- browser_runtime_code(),
         :ok <- ensure_playwright_started(config, timeout),
         {:ok, browser} <- PlaywrightEx.launch_browser(browser(config), timeout: timeout),
         {:ok, context} <- Browser.new_context(browser.guid, timeout: timeout),
         {:ok, %{main_frame: frame}} <- BrowserContext.new_page(context.guid, timeout: timeout) do
      try do
        evaluate(frame, runtime_code, bundled.code, path, mode, test_id, timeout)
      after
        BrowserContext.close(context.guid, timeout: timeout)
        Browser.close(browser.guid, timeout: timeout)
      end
    end
  end

  defp browser_runtime_code do
    Volt.JS.Runtime.Bundler.bundle_file(Volt.Priv.path({:volt, "ts"}, "test/core.ts"))
  end

  defp ensure_playwright_started(%Config{} = config, timeout) do
    opts =
      config.playwright
      |> Keyword.put_new(:timeout, timeout)
      |> Keyword.put_new(:executable, playwright_executable())

    case PlaywrightEx.Supervisor.start_link(opts) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp playwright_executable do
    local = Path.expand("node_modules/.bin/playwright")
    if File.exists?(local), do: local, else: "playwright"
  end

  defp browser(%Config{browsers: [browser | _]}), do: browser
  defp browser(%Config{}), do: :chromium

  defp evaluate(frame, runtime_code, test_code, file, mode, test_id, timeout) do
    Frame.evaluate(frame.guid,
      expression: """
      async ({ runtimeCode, testCode, file, mode, testId }) => {
        (0, eval)(runtimeCode)

        if (mode === 'collect') {
          return globalThis.__voltCollectTestModule(testCode, file)
        }

        if (testId === null || testId === undefined) {
          return globalThis.__voltRunTestModule(testCode, file)
        }

        return globalThis.__voltRunTestModule(testCode, file, testId)
      }
      """,
      is_function: true,
      arg: %{
        "runtimeCode" => runtime_code,
        "testCode" => test_code,
        "file" => file,
        "mode" => Atom.to_string(mode),
        "testId" => test_id
      },
      timeout: timeout
    )
  end
end
