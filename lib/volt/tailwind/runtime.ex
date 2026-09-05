defmodule Volt.Tailwind.Runtime do
  @moduledoc false

  use GenServer

  @name __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  @spec call(String.t() | nil, [String.t()], String.t()) :: {:ok, String.t()} | {:error, term()}
  def call(css, candidates, css_base) do
    GenServer.call(@name, {:compile, css, candidates, css_base}, :infinity)
  end

  @impl true
  def init(:ok), do: {:ok, nil}

  @impl true
  def handle_call({:compile, css, candidates, css_base}, _from, runtime) do
    runtime = runtime || start_runtime()
    result = Volt.JS.Runtime.call(runtime, "compileTailwindCss", [css, candidates, css_base])
    {:reply, normalize_result(result), runtime}
  end

  @impl true
  def terminate(_reason, nil), do: :ok

  def terminate(_reason, runtime) do
    Volt.JS.Runtime.stop(runtime)
    :ok
  end

  defp start_runtime do
    Volt.JS.Runtime.PackageSet.runtime_opts(
      Volt.Tailwind.Loader.runtime_package_set(),
      apis: [:browser, :node],
      handlers: fn runtime -> Volt.Tailwind.Loader.handlers(runtime.node_modules) end,
      define: fn runtime ->
        %{
          "TAILWIND_ROOT" => Volt.JS.Runtime.package_path!(runtime, "tailwindcss"),
          "TAILWIND_DEFAULT_BASE" => File.cwd!()
        }
      end,
      entry: {:volt_asset, "compilers/tailwind.ts"}
    )
    |> Volt.JS.Runtime.ensure!()
  end

  defp normalize_result({:ok, result}) when is_binary(result), do: {:ok, result}
  defp normalize_result({:ok, _result}), do: {:error, :unexpected_result}
  defp normalize_result({:error, _reason} = error), do: error
end
