defmodule Volt.VueImports do
  @moduledoc false

  @doc "Extract import specifiers from a Vue SFC's script blocks."
  @spec extract(String.t()) :: {:ok, [String.t()]}
  def extract(source) do
    case Vize.parse_sfc(source) do
      {:ok, descriptor} ->
        imports =
          [descriptor.script, descriptor.script_setup]
          |> Enum.reject(&is_nil/1)
          |> Enum.flat_map(fn block ->
            lang = block[:lang] || "js"

            case OXC.imports(block.content, "script.#{lang}") do
              {:ok, imports} -> imports
              {:error, _} -> []
            end
          end)

        {:ok, imports}

      {:error, _} ->
        {:ok, []}
    end
  end
end
