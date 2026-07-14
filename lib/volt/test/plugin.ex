defmodule Volt.Test.Plugin do
  @moduledoc """
  Internal Volt plugin that exposes test-runner virtual modules.

  Test files can import the public `volt:test` API while the Elixir runner
  provides the actual functions as globals inside QuickBEAM or the browser.
  The plugin also exposes Volt client runtime modules for dogfood tests without
  path drilling into `priv/ts/client`.
  """

  @behaviour Volt.Plugin

  @test_entry "virtual:volt/test-entry"
  @test_modules %{
    "volt:test" => "virtual:volt/test",
    "volt:test/browser" => "virtual:volt/test/browser"
  }
  @test_module_ids MapSet.new(Map.values(@test_modules))

  @doc false
  @spec entry_specifier() :: String.t()
  def entry_specifier, do: @test_entry

  @impl true
  def name, do: "volt-test"

  def resolve(@test_entry, _importer, opts) do
    if Keyword.has_key?(opts, :test_file), do: {:ok, @test_entry}
  end

  def resolve(specifier, importer, _opts), do: resolve(specifier, importer)

  @impl true
  def resolve("volt:client/" <> relative, _importer) do
    {:volt, "ts"}
    |> Volt.Priv.path(Path.join("client", relative))
    |> resolve_client_runtime("volt:client/#{relative}")
  end

  def resolve(specifier, _importer) do
    case @test_modules do
      %{^specifier => id} -> {:ok, id}
      _other -> nil
    end
  end

  def load(@test_entry, opts) do
    imports =
      opts
      |> Keyword.fetch!(:setup_files)
      |> Stream.concat([Keyword.fetch!(opts, :test_file)])
      |> Enum.map(&"import #{inspect(&1)};")

    source =
      Volt.Priv.js!({:volt, "ts"}, "test/entry.ts", [], splices: [imports: imports])

    {:ok, source}
  end

  def load(specifier, _opts), do: load(specifier)

  @impl true
  def load(id) do
    if MapSet.member?(@test_module_ids, id) do
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
