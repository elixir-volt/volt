defmodule Volt.NPM do
  @moduledoc """
  Installs exact npm package sets into Volt's isolated, npm_ex-backed cache.

  Frameworks and plugins can use this API for JavaScript dependencies they own
  without adding those packages to an application's `node_modules` directory.
  The returned directory is stable for the normalized package set and can be
  passed to `Volt.Builder` as a package directory or scoped package root.
  """

  @type install_result :: %{install_dir: String.t(), node_modules: String.t()}

  @doc "Install a package map and return its isolated cache directories."
  @spec install!(%{String.t() => String.t()}, keyword()) :: install_result()
  def install!(packages, opts \\ []) when is_map(packages) do
    Enum.each(packages, fn
      {name, version}
      when is_binary(name) and name != "" and is_binary(version) and version != "" ->
        :ok

      package ->
        raise ArgumentError,
              "expected npm packages to contain non-empty string names and versions, got: #{inspect(package)}"
    end)

    Volt.JS.Runtime.Installer.install!(packages, opts)
  end
end
