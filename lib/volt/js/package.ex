defmodule Volt.JS.Package do
  @moduledoc false

  def subpath_for(specifier) do
    case NPM.Resolution.PackageResolver.split_specifier(specifier) do
      {_, nil} -> "."
      {_, subpath} -> subpath
    end
  end
end
