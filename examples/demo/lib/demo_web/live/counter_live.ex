defmodule DemoWeb.CounterLive do
  use DemoWeb, :live_view
  use LiveVueNext

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def render(assigns) do
    ~VUE"""
    <div class="space-y-6 max-w-md mx-auto mt-12">
      <h1 class="text-3xl font-bold text-center">Volt + LiveVueNext</h1>
      <p class="text-center text-gray-500">Vue templates rendered as native LiveView — no JS runtime</p>

      <div class="text-center space-y-4">
        <p class="text-6xl font-mono tabular-nums">{{ count }}</p>
        <div class="flex justify-center gap-3">
          <button phx-click="dec" class="px-5 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition">−</button>
          <button phx-click="reset" class="px-5 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition">Reset</button>
          <button phx-click="inc" class="px-5 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition">+</button>
        </div>
      </div>

      <nav class="text-center text-sm">
        <a href="/todo" class="text-blue-500 hover:underline">Todo List →</a>
      </nav>
    </div>
    """
  end

  def handle_event("inc", _, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}
  def handle_event("dec", _, socket), do: {:noreply, update(socket, :count, &(&1 - 1))}
  def handle_event("reset", _, socket), do: {:noreply, assign(socket, count: 0)}
end
