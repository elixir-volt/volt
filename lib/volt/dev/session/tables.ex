defmodule Volt.Dev.Session.Tables do
  @moduledoc "Generation-specific handles to ETS tables owned by a development session."

  @enforce_keys [:owner, :generation, :cache, :imports, :globs, :styles, :modules, :assets]
  defstruct [{:stylesheet_worker, nil} | @enforce_keys]
end
