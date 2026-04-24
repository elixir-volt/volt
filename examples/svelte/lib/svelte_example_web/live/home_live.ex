defmodule SvelteExampleWeb.HomeLive do
  use SvelteExampleWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="app"></div>
    </Layouts.app>
    """
  end
end
