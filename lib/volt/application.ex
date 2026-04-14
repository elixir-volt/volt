defmodule Volt.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Volt.Cache.create_table()
    Volt.DepGraph.create_table()

    children = [
      {Registry, keys: :duplicate, name: Volt.HMR.Registry},
      {Volt.Tailwind, Volt.Config.tailwind()}
    ]

    opts = [strategy: :one_for_one, name: Volt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
