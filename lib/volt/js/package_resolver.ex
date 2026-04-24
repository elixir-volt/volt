defmodule Volt.JS.PackageResolver do
  @moduledoc false

  @default_extensions Volt.JS.Extensions.node_resolvable()

  def resolve(specifier, from_dir, opts \\ []) do
    NPM.PackageResolver.resolve(specifier, from_dir, with_default_extensions(opts))
  end

  def relative_import_path(importer, target, project_root) do
    NPM.PackageResolver.relative_import_path(importer, target, project_root)
  end

  def relative?(specifier), do: NPM.PackageResolver.relative?(specifier)

  defp with_default_extensions(opts) do
    Keyword.put_new(opts, :extensions, @default_extensions)
  end
end
