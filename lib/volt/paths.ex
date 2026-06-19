defmodule Volt.Paths do
  @moduledoc "Shared path conventions used by Volt."

  @paths [
    assets: "assets",
    assets_dir: "assets/",
    lib: "lib/",
    entry: "assets/js/app.ts",
    static: "priv/static/assets",
    static_css: "priv/static/assets/css",
    prefix: "/assets"
  ]

  @ignored_dirs ~w(node_modules _build deps .git)

  for {name, value} <- @paths do
    def unquote(name)(), do: unquote(value)
  end

  def ignored_dirs, do: @ignored_dirs
  def ignored_globs, do: Enum.map(@ignored_dirs, &"#{&1}/**")
end
