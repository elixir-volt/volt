defmodule Volt.Dev.Prebundled do
  @moduledoc false
  # Which sets of vendor options have been pre-bundled since the sources last
  # changed.
  #
  # Phoenix initializes plugs on every request in development, so the dev
  # server asks for a pre-bundle on every request. Scanning the sources each
  # time is wasted work, and concurrent requests bundling at once would replace
  # cache files that others are reading.

  @table :volt_vendor_prebundled

  def create_table, do: Volt.ETS.create_named_set(@table)

  @doc """
  Run `prebundle` unless it already ran for `opts` since `forget/0`. Callers
  with the same options take turns, so one bundles and the rest find it done.
  """
  @spec ensure(keyword(), (-> term())) :: :ok
  def ensure(opts, prebundle) when is_function(prebundle, 0) do
    :global.trans(
      {{__MODULE__, opts}, self()},
      fn ->
        if :ets.lookup(@table, opts) == [] do
          prebundle.()
          Volt.ETS.put(@table, {opts})
        end
      end,
      [node()]
    )

    :ok
  end

  @doc "Make `ensure/2` run again. A changed source may import a package that is not bundled yet."
  @spec forget() :: :ok
  def forget, do: Volt.ETS.clear(@table)
end
