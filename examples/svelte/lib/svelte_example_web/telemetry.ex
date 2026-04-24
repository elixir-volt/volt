defmodule SvelteExampleWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg), do: Supervisor.start_link(__MODULE__, arg, name: __MODULE__)

  @impl true
  def init(_arg) do
    children = [{:telemetry_poller, measurements: [], period: 10_000}]
    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics, do: [summary("phoenix.endpoint.stop.duration")]
end
