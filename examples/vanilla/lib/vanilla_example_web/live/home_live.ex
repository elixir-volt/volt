defmodule VanillaExampleWeb.HomeLive do
  use VanillaExampleWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def handle_event("increment", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto mt-12 max-w-2xl space-y-8 px-6 pb-12">
        <header class="flex items-center gap-4">
          <img src={~p"/assets/images/volt.svg"} alt="" class="h-10 w-10 text-amber-500" />
          <div>
            <h1 class="text-4xl font-black tracking-tight text-slate-950">Volt + Phoenix</h1>
            <p class="text-sm text-slate-500">Plain TypeScript with LiveView</p>
          </div>
        </header>

        <div class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <h2 class="mb-3 text-xs font-bold uppercase tracking-widest text-slate-400">Counter</h2>
          <button
            type="button"
            class="rounded-full bg-amber-600 px-5 py-2.5 font-semibold text-white shadow-md shadow-amber-600/25 transition hover:-translate-y-0.5 hover:bg-amber-700"
            phx-click="increment"
          >
            Count is {@count}
          </button>
          <p class="mt-3 text-sm text-slate-500">Doubled: {@count * 2}</p>
        </div>

        <div
          id="clock"
          class="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"
          phx-hook="Clock"
        >
          <h2 class="mb-3 text-xs font-bold uppercase tracking-widest text-slate-400">LiveView Hook</h2>
          <p class="text-lg font-mono text-slate-700" data-time>--:--:--</p>
        </div>

        <footer class="text-center text-xs text-slate-400">
          Mode: <span id="mode" phx-hook="EnvMode">--</span>
        </footer>
      </main>
    </Layouts.app>
    """
  end
end
