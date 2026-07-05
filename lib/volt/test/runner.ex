defmodule Volt.Test.Runner do
  @moduledoc """
  Executes Volt JavaScript and TypeScript test files in a QuickBEAM runtime.

  This is the first, intentionally small, runner layer. It supports test files
  that use global Vitest-like helpers (`describe`, `test`, `it`, `beforeEach`,
  `afterEach`, and `expect`) provided by `priv/ts/test/core.ts`.

  Test files may import helpers from `volt:test`; those virtual imports are
  stripped before bundling because the runtime provides the helpers as globals.
  Local relative JS/TS module graphs are bundled before execution.
  """

  alias Volt.JS.Runtime
  alias Volt.Test.Config

  @type result :: map()

  @spec run_file(Path.t(), keyword()) :: {:ok, result()} | {:error, term()}
  def run_file(path, opts \\ []) do
    config = Keyword.get_lazy(opts, :config, fn -> Config.read(Keyword.get(opts, :profile)) end)
    compile_opts = Keyword.get(opts, :compile_opts, [])
    timeout = Keyword.get(opts, :timeout, config.timeout)

    with {:ok, bundled} <- Volt.Test.Bundler.bundle_file(path, compile_opts),
         {:ok, runtime} <- start_runtime(config, opts) do
      try do
        Runtime.call(runtime, "__voltRunTestModule", [bundled.code, path], timeout: timeout)
      after
        Runtime.stop(runtime)
      end
    end
  end

  defp start_runtime(%Config{} = config, opts) do
    runtime_opts =
      config.js_runtime
      |> Keyword.merge(Keyword.get(opts, :js_runtime, []))
      |> Keyword.put_new(:entry, {:volt_asset, "test/core.ts"})
      |> Keyword.put_new(:install_dir, install_dir())

    Runtime.start(runtime_opts)
  end

  defp install_dir do
    Path.join(System.tmp_dir!(), "volt-test-runtime")
  end
end
