defmodule Volt.Dev.Session.State do
  @moduledoc "Owns the compilation tables for one development-session generation."

  use GenServer
  alias Volt.Dev.Session.Tables

  def start_link(opts), do: GenServer.start_link(__MODULE__, :ok, opts)

  def tables(server), do: GenServer.call(server, :tables)

  def attach_stylesheet(server, worker), do: GenServer.call(server, {:attach_stylesheet, worker})

  @impl true
  def init(:ok) do
    tables =
      Map.new([:cache, :imports, :globs, :styles, :modules], fn kind ->
        {kind, :ets.new(kind, [:set, :public, read_concurrency: true])}
      end)

    {:ok, struct!(Tables, Map.merge(tables, %{owner: self(), generation: make_ref()}))}
  end

  @impl true
  def handle_call(:tables, _from, tables), do: {:reply, tables, tables}

  def handle_call({:attach_stylesheet, worker}, _from, tables) do
    tables = %{tables | stylesheet_worker: worker}
    {:reply, tables, tables}
  end
end
