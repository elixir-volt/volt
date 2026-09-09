defmodule Volt.Dev.Session.Watcher do
  @moduledoc "Starts a watcher using the current session-owned table handles."

  def start_link(opts) do
    {state_owner, opts} = Keyword.pop!(opts, :state_owner)
    worker = GenServer.whereis(Keyword.fetch!(opts, :tailwind_worker))
    tables = Volt.Dev.Session.State.attach_stylesheet(state_owner, worker)

    opts =
      Keyword.put_new(
        opts,
        :configuration_signature,
        opts
        |> Keyword.drop([:name, :state_owner, :tailwind_worker, :tailwind_runtime])
        |> Map.new()
      )

    Volt.Watcher.start_link(Keyword.put(opts, :tables, tables))
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      significant: true
    }
  end
end
