defmodule Volt.Builder.Compiler do
  @moduledoc false

  def compile(path, source, ctx) do
    Volt.Pipeline.compile(path, source,
      target: ctx.target,
      import_source: ctx.import_source,
      mode: :production,
      define: ctx.define,
      plugins: ctx.plugins,
      loaders: ctx.loaders
    )
  end
end
