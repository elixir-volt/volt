defmodule Volt.Test.BrowserRunner do
  @moduledoc """
  Executes Volt JavaScript and TypeScript tests inside a real browser via PlaywrightEx.

  This runner is intentionally small and mirrors `Volt.Test.Runner`'s result
  contract so ExUnit integration can switch between QuickBEAM and browser
  execution without changing assertions or reporting.

  The browser belongs to the run (see `Volt.Test.Browser`); each call opens a
  context in it, loads the file's bundled module and closes the context again.
  """

  alias Volt.Test.Browser
  alias Volt.Test.Config

  @type result :: map()

  @spec collect_file(Path.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def collect_file(path, opts \\ []) do
    with {:ok, tests} <- call_browser_runtime(path, :collect, nil, opts) do
      tests = Enum.map(tests, &Volt.Test.Result.Metadata.from_map!/1)
      Volt.Test.Shared.add_source_lines(path, tests)
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

  defp call_browser_runtime(path, mode, test_id, opts) do
    config = Keyword.fetch!(opts, :config)
    timeout = Keyword.get(opts, :timeout, config.timeout)

    with {:ok, _pid} <- Browser.Supervisor.start(config) do
      Browser.with_page(browser(config), timeout, fn frame ->
        with {:ok, module_url} <-
               Browser.module(path, Volt.Test.Shared.bundle_opts(path, config, opts)) do
          evaluate(frame, module_url, path, mode, test_id, timeout)
        end
      end)
    end
  end

  defp browser(%Config{browsers: [browser | _]}), do: browser
  defp browser(%Config{}), do: :chromium

  # The page the run opens carries the test runtime, so the frame already has
  # `__voltExecuteBrowserTest`.
  defp evaluate(frame, test_url, file, mode, test_id, timeout) do
    frame_evaluate(frame.guid,
      expression: "payload => globalThis.__voltExecuteBrowserTest(payload)",
      is_function: true,
      arg: %{
        "testUrl" => test_url,
        "file" => file,
        "mode" => Atom.to_string(mode),
        "testId" => test_id
      },
      timeout: timeout
    )
  end

  # The playwright_ex dependency is only present in test environments, so its
  # functions are called without compile-time references.
  defp frame_evaluate(frame_guid, opts) do
    apply(PlaywrightEx.Frame, :evaluate, [
      frame_guid,
      [connection: Browser.Supervisor.connection()] ++ opts
    ])
  end
end
