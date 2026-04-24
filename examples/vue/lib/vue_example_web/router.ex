defmodule VueExampleWeb.Router do
  use VueExampleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VueExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", VueExampleWeb do
    pipe_through :browser
    live "/", HomeLive
  end
end
