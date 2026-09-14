defmodule Volt.Dev.Session.Watcher do
  @moduledoc "Starts a watcher using the current session-owned table handles."

  def start_link(opts) do
    {state_owner, opts} = Keyword.pop!(opts, :state_owner)
    worker = GenServer.whereis(Keyword.fetch!(opts, :tailwind_worker))
    tables = Volt.Dev.Session.State.attach_stylesheet(state_owner, worker)

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
