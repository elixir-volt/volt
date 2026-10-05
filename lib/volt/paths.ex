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

  @root {__MODULE__, :root}

  @doc """
  Remember the working directory as the project root. Called when Volt starts.

  The working directory belongs to the whole VM, and Mix changes it while it
  compiles a dependency, as `Phoenix.CodeReloader` does for a reloadable path
  dependency during a request. A relative path resolved in that window lands in
  the dependency's directory, so the development server resolves paths from the
  root captured here instead.
  """
  @spec capture_root() :: :ok
  def capture_root, do: :persistent_term.put(@root, File.cwd!())

  @doc "The project root: the working directory when Volt started, or the current one."
  @spec root() :: String.t()
  def root, do: :persistent_term.get(@root, nil) || File.cwd!()

  @doc "Expand a path from the project root."
  @spec expand(String.t()) :: String.t()
  def expand(path), do: Path.expand(path, root())

  def ignored_dirs, do: @ignored_dirs
  def ignored_globs, do: Enum.map(@ignored_dirs, &"#{&1}/**")
end
