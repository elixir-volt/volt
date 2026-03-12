defmodule Volt.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: Volt.HMR.Registry},
      {Volt.Tailwind, Application.get_env(:volt, :tailwind, [])}
    ]

    opts = [strategy: :one_for_one, name: Volt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
