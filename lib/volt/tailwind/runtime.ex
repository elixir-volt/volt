defmodule Volt.Tailwind.Runtime do
  @moduledoc false

  use GenServer

  @name __MODULE__

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name, @name))
  end

  @spec call(String.t() | nil, [String.t()], String.t()) :: {:ok, String.t()} | {:error, term()}
  def call(css, candidates, css_base, server \\ @name) do
    GenServer.call(server, {:compile, css, candidates, css_base}, :infinity)
  end

  @doc "Compile and return source/dependency metadata for development invalidation."
  def compile_metadata(css, candidates, css_base, server) do
    GenServer.call(server, {:compile_metadata, css, candidates, css_base}, :infinity)
  end

  @doc "Compile once in an isolated runtime, releasing it when compilation finishes."
  @spec compile_once(String.t() | nil, [String.t()], String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def compile_once(css, candidates, css_base, scan \\ nil) do
    runtime = start_runtime()

    try do
      runtime
      |> Volt.JS.Runtime.call("compileTailwindCss", [css, candidates, css_base, scan])
      |> normalize_result()
    after
      if Process.alive?(runtime.pid), do: Volt.JS.Runtime.stop(runtime)
    end
  end

  @impl true
  def init(:ok) do
    Process.flag(:trap_exit, true)
    {:ok, nil}
  end

  @impl true
  def handle_call({:compile_metadata, css, candidates, css_base}, _from, runtime) do
    runtime = if runtime && Process.alive?(runtime.pid), do: runtime, else: start_runtime()

    case Volt.JS.Runtime.call(runtime, "compileTailwindCss", [
           css,
           candidates,
           css_base,
           nil,
           true
         ]) do
      {:ok, result} -> {:reply, {:ok, Volt.Tailwind.Metadata.decode(result)}, runtime}
      {:error, _} = error -> {:reply, error, runtime}
    end
  end

  def handle_call({:compile, css, candidates, css_base}, _from, runtime) do
    runtime = if runtime && Process.alive?(runtime.pid), do: runtime, else: start_runtime()

    try do
      result = Volt.JS.Runtime.call(runtime, "compileTailwindCss", [css, candidates, css_base])
      {:reply, normalize_result(result), runtime}
    catch
      :exit, reason ->
        if Process.alive?(runtime.pid), do: Volt.JS.Runtime.stop(runtime)
        {:reply, {:error, {:compiler_exit, reason}}, nil}
    end
  end

  @impl true
  def handle_info({:EXIT, pid, _reason}, %{pid: pid}), do: {:noreply, nil}
  def handle_info({:EXIT, _pid, _reason}, runtime), do: {:noreply, runtime}

  @impl true
  def terminate(_reason, nil), do: :ok

  def terminate(_reason, runtime) do
    if Process.alive?(runtime.pid), do: Volt.JS.Runtime.stop(runtime)
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
