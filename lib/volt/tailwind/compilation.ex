defmodule Volt.Tailwind.Compilation do
  @moduledoc "Retained stylesheet compilation inputs for a Tailwind context."

  defstruct css: nil, base: nil, minify: false

  def new(opts) do
    %__MODULE__{
      css: Keyword.get(opts, :css),
      base: Path.expand(Keyword.get(opts, :css_base) || File.cwd!()),
      minify: Keyword.get(opts, :minify, false)
    }
  end

  def update(%__MODULE__{} = compilation, opts) do
    new(
      css: Keyword.get(opts, :css, compilation.css),
      css_base: Keyword.get(opts, :css_base, compilation.base),
      minify: Keyword.get(opts, :minify, compilation.minify)
    )
  end
end
