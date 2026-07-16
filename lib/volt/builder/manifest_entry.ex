defmodule Volt.Builder.ManifestEntry do
  @moduledoc "Manifest entry written to production `manifest.json`."

  @derive Jason.Encoder
  defstruct file: nil,
            src: nil,
            isEntry: false,
            imports: [],
            dynamicImports: [],
            css: [],
            assets: []

  @type t :: %__MODULE__{
          file: String.t(),
          src: String.t(),
          isEntry: boolean(),
          imports: [String.t()],
          dynamicImports: [String.t()],
          css: [String.t()],
          assets: [String.t()]
        }

  def js(src, file, opts \\ []) do
    %__MODULE__{src: src, file: file, isEntry: Keyword.get(opts, :entry, false)}
  end

  def css(src, file, assets), do: %__MODULE__{src: src, file: file, assets: assets}

  def asset(src, file), do: %__MODULE__{src: src, file: file}
end
