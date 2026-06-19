defmodule Volt.Paths do
  @moduledoc "Shared path conventions used by Volt."

  @assets "assets"
  @assets_dir "assets/"
  @lib "lib/"
  @entry "assets/js/app.ts"
  @static "priv/static/assets"
  @static_css "priv/static/assets/css"
  @prefix "/assets"
  @ignored_dirs ~w(node_modules _build deps .git)

  def assets, do: @assets
  def assets_dir, do: @assets_dir
  def lib, do: @lib
  def entry, do: @entry
  def static, do: @static
  def static_css, do: @static_css
  def prefix, do: @prefix
  def ignored_dirs, do: @ignored_dirs
  def ignored_globs, do: Enum.map(@ignored_dirs, &"#{&1}/**")
end
