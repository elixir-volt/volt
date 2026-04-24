defmodule VueExampleWeb.HomeLive do
  use VueExampleWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="app"></div>
    </Layouts.app>
    """
  end
end
