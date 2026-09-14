defmodule Volt.Tailwind.Metadata do
  @moduledoc "Compiler-discovered inputs decoded at the JavaScript boundary."

  defstruct [:code, :root, dependencies: [], sources: []]

  def decode(%{
        "code" => code,
        "root" => root,
        "dependencies" => dependencies,
        "sources" => sources
      }) do
    %__MODULE__{
      code: code,
      root: root(root),
      dependencies: dependencies,
      sources:
        Enum.map(sources, fn %{"base" => base, "pattern" => pattern, "negated" => negated} ->
          %Oxide.Source{base: base, pattern: pattern, negated: negated}
        end)
    }
  end

  defp root(nil), do: :automatic
  defp root("none"), do: :none

  defp root(%{"base" => base, "pattern" => pattern}),
    do: %Oxide.Source{base: base, pattern: pattern, negated: false}
end
