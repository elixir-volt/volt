defmodule Volt.Test.Browser.Supervisor do
  @moduledoc """
  Supervises what a test run keeps for its browser tests: the Playwright
  driver and `Volt.Test.Browser`, which launches browsers in it.

  Starting the driver and launching a browser each cost more than running a
  test, so both outlive the tests. The tree is started under `Volt.Supervisor`
  on first use, with the `:playwright` options of the configuration that
  started it, and goes away only with the VM.
  """

  use Supervisor

  alias Volt.Test.Config

  @playwright Volt.Test.Browser.Playwright

  @doc """
  Start the tree, or find it already running.

  The tree lives under `Volt.Supervisor`, so Volt's application is started
  first: a project that depends on Volt with `runtime: false` has not started
  it.
  """
  @spec start(Config.t()) :: {:ok, pid()} | {:error, term()}
  def start(%Config{} = config) do
    with {:ok, _started} <- Application.ensure_all_started(:volt) do
      case Supervisor.start_child(Volt.Supervisor, {__MODULE__, config}) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc false
  def child_spec(config) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [config]},
      restart: :temporary,
      type: :supervisor
    }
  end

  @doc false
  def start_link(%Config{} = config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  @impl true
  def init(%Config{} = config) do
    # The driver is a port and the browsers are its children, so a driver
    # that went away takes the launched browsers with it.
    children = [
      %{
        id: @playwright,
        start: {PlaywrightEx.Supervisor, :start_link, [playwright_opts(config)]},
        type: :supervisor
      },
      Volt.Test.Browser
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @doc "The Playwright connection the run's browsers belong to."
  @spec connection() :: GenServer.name()
  def connection, do: Module.concat(@playwright, "Connection")

  defp playwright_opts(%Config{} = config) do
    config.playwright
    |> Keyword.put_new(:timeout, config.timeout)
    |> Keyword.put_new(:executable, playwright_executable())
    |> Keyword.put(:name, @playwright)
  end

  defp playwright_executable do
    local = Path.expand("node_modules/playwright/cli.js", Volt.Paths.root())
    if File.exists?(local), do: local, else: "playwright"
  end
end
