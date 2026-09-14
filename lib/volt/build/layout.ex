defmodule Volt.Build.Layout do
  @moduledoc "Output locations for a complete frontend build."

  @enforce_keys [:scripts, :styles]
  defstruct [:scripts, :styles]

  @type t :: %__MODULE__{scripts: String.t(), styles: String.t()}

  @spec new(:split | :flat, String.t()) :: t()
  def new(layout, assets_dir \\ "") do
    if assets_dir != "" and
         (Path.type(assets_dir) != :relative or
            Enum.any?(Path.split(assets_dir), &(&1 in [".", ".."])) or
            String.contains?(assets_dir, ["\\", ":", <<0>>])) do
      raise ArgumentError, "assets_dir must be a relative directory within outdir"
    end

    layout = preset(layout)

    %__MODULE__{
      scripts: join(assets_dir, layout.scripts),
      styles: join(assets_dir, layout.styles)
    }
  end

  defp join("", suffix), do: suffix
  defp join(prefix, ""), do: prefix
  defp join(prefix, suffix), do: Path.join(prefix, suffix)

  defp preset(:split), do: %__MODULE__{scripts: "js", styles: "css"}
  defp preset(:flat), do: %__MODULE__{scripts: "", styles: ""}

  defp preset(other) do
    raise ArgumentError, "expected output_layout to be :split or :flat, got: #{inspect(other)}"
  end
end
