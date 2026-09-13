defmodule Volt.Dev.Session.State do
  @moduledoc "Owns the compilation tables for one development-session generation."

  use GenServer
  alias Volt.Dev.Session.Tables

  defstruct [:tables, :configuration]

  def start_link(opts) do
    {configuration, opts} = Keyword.pop(opts, :configuration)
    GenServer.start_link(__MODULE__, configuration, opts)
  end

  def configuration_matches?(server, signature),
    do: GenServer.call(server, {:configuration_matches, signature})

  def tables(server), do: GenServer.call(server, :tables)

  def attach_stylesheet(server, worker), do: GenServer.call(server, {:attach_stylesheet, worker})

  @impl true
  def init(configuration) do
    tables =
      Map.new([:cache, :imports, :globs, :styles, :modules, :assets], fn kind ->
        {kind, :ets.new(kind, [:set, :public, read_concurrency: true])}
      end)

    tables = struct!(Tables, Map.merge(tables, %{owner: self(), generation: make_ref()}))
    {:ok, %__MODULE__{tables: tables, configuration: configuration}}
  end

  @impl true
  def handle_call(:tables, _from, state), do: {:reply, state.tables, state}

  def handle_call({:configuration_matches, signature}, _from, state),
    do: {:reply, state.configuration == signature, state}

  def handle_call({:attach_stylesheet, worker}, _from, state) do
    tables = %{state.tables | stylesheet_worker: worker}
    {:reply, tables, %{state | tables: tables}}
  end
end
