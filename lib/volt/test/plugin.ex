defmodule Volt.Test.Plugin do
  @moduledoc """
  Internal Volt plugin that exposes test-runner virtual modules.

  Test files can import the public `volt:test` API while the Elixir runner
  provides the actual functions as globals inside QuickBEAM or the browser.
  The plugin also exposes Volt client runtime modules for dogfood tests without
  path drilling into `priv/ts/client`.
  """

  @behaviour Volt.Plugin

  @test_modules MapSet.new(["volt:test", "volt:test/browser"])

  @impl true
  def name, do: "volt-test"

  @impl true
  def resolve("volt:client/" <> relative, _importer) do
    {:volt, "ts"}
    |> Volt.Priv.path(Path.join("client", relative))
    |> resolve_client_runtime("volt:client/#{relative}")
  end

  def resolve(specifier, _importer) do
    if MapSet.member?(@test_modules, specifier), do: {:ok, specifier}
  end

  @impl true
  def load(specifier) do
    if MapSet.member?(@test_modules, specifier) do
      {:ok, test_api_module()}
    end
  end

  defp resolve_client_runtime(base, specifier) do
    case Enum.find(candidate_paths(base), &File.regular?/1) do
      nil -> {:error, {:module_not_found, specifier, nil}}
      path -> {:ok, path}
    end
  end

  defp candidate_paths(base) do
    exact_and_exts = Enum.map(Volt.JS.Extensions.node_resolvable_with_exact(), &(base <> &1))
    index_files = Enum.map(Volt.JS.Extensions.node_resolvable(), &Path.join(base, "index" <> &1))
    exact_and_exts ++ index_files
  end

  defp test_api_module do
    """
    const api = globalThis;

    export const describe = api.describe;
    export const test = api.test;
    export const it = api.it;
    export const beforeEach = api.beforeEach;
    export const afterEach = api.afterEach;
    export const expect = api.expect;
    """
  end
end
