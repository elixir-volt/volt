defmodule SvelteExampleWeb.Layouts do
  use SvelteExampleWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main class="min-h-screen bg-slate-50 px-4 py-1 text-slate-900">
      {render_slot(@inner_block)}
    </main>
    """
  end
end
