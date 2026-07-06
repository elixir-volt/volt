defmodule Volt.Test.BrowserRunner do
  @moduledoc """
  Executes Volt JavaScript and TypeScript tests inside a real browser via PlaywrightEx.

  This runner is intentionally small and mirrors `Volt.Test.Runner`'s result
  contract so ExUnit integration can switch between QuickBEAM and browser
  execution without changing assertions or reporting.
  """

  alias Volt.Test.Config

  @type result :: map()

  @spec collect_file(Path.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def collect_file(path, opts \\ []) do
    with {:ok, tests} <- call_browser_runtime(path, :collect, nil, opts) do
      tests = Enum.map(tests, &Volt.Test.Result.Metadata.from_map!/1)
      add_source_lines(path, tests)
    end
  end

  @spec run_file(Path.t(), keyword()) :: {:ok, result()} | {:error, term()}
  def run_file(path, opts \\ []) do
    with {:ok, result} <- call_browser_runtime(path, :run, nil, opts) do
      {:ok, Volt.Test.Result.from_map!(result)}
    end
  end

  @spec run_test(Path.t(), integer(), keyword()) :: {:ok, result()} | {:error, term()}
  def run_test(path, test_id, opts \\ []) when is_integer(test_id) do
    with {:ok, result} <- call_browser_runtime(path, :run, test_id, opts) do
      {:ok, Volt.Test.Result.from_map!(result)}
    end
  end

  defp add_source_lines(path, tests) do
    with {:ok, source} <- File.read(path),
         {:ok, lines} <- Volt.Test.Lines.test_lines(source, Path.basename(path)) do
      {:ok,
       tests
       |> Enum.zip(lines)
       |> Enum.map(fn {test, line} -> %{test | line: line} end)}
    else
      {:error, _} -> {:ok, tests}
    end
  end

  defp call_browser_runtime(path, mode, test_id, opts) do
    config = Keyword.fetch!(opts, :config)
    timeout = Keyword.get(opts, :timeout, config.timeout)

    with {:ok, bundled} <- Volt.Builder.bundle(test_bundle_opts(path, config, opts)),
         {:ok, runtime_code} <- browser_runtime_code(),
         :ok <- ensure_playwright_started(config, timeout),
         {:ok, browser} <- launch_browser(browser(config), timeout: timeout),
         {:ok, context} <- browser_new_context(browser.guid, timeout: timeout),
         {:ok, %{main_frame: frame}} <- browser_context_new_page(context.guid, timeout: timeout) do
      try do
        evaluate(frame, runtime_code, bundled.code, path, mode, test_id, timeout)
      after
        browser_context_close(context.guid, timeout: timeout)
        browser_close(browser.guid, timeout: timeout)
      end
    end
  end

  defp test_bundle_opts(path, %Config{} = config, opts) do
    config.bundle
    |> Keyword.merge(Keyword.get(opts, :bundle, []))
    |> Keyword.put(:entry, path)
    |> Keyword.put_new(:format, :iife)
    |> Keyword.put_new(:minify, false)
    |> Keyword.put_new(:sourcemap, true)
    |> Keyword.put_new(:code_splitting, false)
    |> Keyword.put_new(:mode, "test")
    |> Keyword.update(:plugins, [Volt.Test.Plugin], &[Volt.Test.Plugin | List.wrap(&1)])
  end

  defp browser_runtime_code do
    Volt.JS.Runtime.Bundler.bundle_file(Volt.Priv.path({:volt, "ts"}, "test/browser.ts"))
  end

  defp ensure_playwright_started(%Config{} = config, timeout) do
    opts =
      config.playwright
      |> Keyword.put_new(:timeout, timeout)
      |> Keyword.put_new(:executable, playwright_executable())

    case playwright_supervisor_start_link(opts) do
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
    with {:ok, _} <-
           frame_evaluate(frame.guid,
             expression: runtime_code,
             is_function: false,
             arg: nil,
             timeout: timeout
           ) do
      frame_evaluate(frame.guid,
        expression: "payload => globalThis.__voltExecuteBrowserTest(payload)",
        is_function: true,
        arg: %{
          "testCode" => test_code,
          "file" => file,
          "mode" => Atom.to_string(mode),
          "testId" => test_id
        },
        timeout: timeout
      )
    end
  end

  defp playwright_supervisor_start_link(opts) do
    apply(PlaywrightEx.Supervisor, :start_link, [opts])
  end

  defp launch_browser(browser, opts) do
    apply(PlaywrightEx, :launch_browser, [browser, opts])
  end

  defp browser_new_context(browser_guid, opts) do
    apply(PlaywrightEx.Browser, :new_context, [browser_guid, opts])
  end

  defp browser_close(browser_guid, opts) do
    apply(PlaywrightEx.Browser, :close, [browser_guid, opts])
  end

  defp browser_context_new_page(context_guid, opts) do
    apply(PlaywrightEx.BrowserContext, :new_page, [context_guid, opts])
  end

  defp browser_context_close(context_guid, opts) do
    apply(PlaywrightEx.BrowserContext, :close, [context_guid, opts])
  end

  defp frame_evaluate(frame_guid, opts) do
    apply(PlaywrightEx.Frame, :evaluate, [frame_guid, opts])
  end
end
