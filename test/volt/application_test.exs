defmodule Volt.ApplicationTest do
  use ExUnit.Case, async: true

  test "Tailwind processes start before watchers, so they stop after them" do
    # `Supervisor.which_children/1` lists children in reverse start order.
    started =
      Volt.Supervisor
      |> Supervisor.which_children()
      |> Enum.map(fn {id, _pid, _type, _modules} -> id end)
      |> Enum.reverse()

    position = fn id -> Enum.find_index(started, &(&1 == id)) end

    for tailwind <- [
          Volt.Tailwind.Registry,
          Volt.Tailwind.WorkerSupervisor,
          Volt.Tailwind.Runtime
        ] do
      assert position.(tailwind) < position.(Volt.Dev.WatcherSupervisor)
    end
  end
end
