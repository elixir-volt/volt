defmodule SvelteExampleWeb.ErrorHTML do
  use SvelteExampleWeb, :html

  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
