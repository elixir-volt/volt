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

  @doc "Return conflicting identities; identical shared entries are permitted."
  def conflicts(left, right) do
    for {key, entry} <- left,
        Map.has_key?(right, key) and right[key] != entry,
        do: key
  end

  def js(src, file, opts \\ []) do
    %__MODULE__{src: src, file: file, isEntry: Keyword.get(opts, :entry, false)}
  end

  def css(src, file, assets), do: %__MODULE__{src: src, file: file, assets: assets}
  def asset(src, file), do: %__MODULE__{src: src, file: file}

  @doc "Prefix emitted paths, preserving imports and dynamicImports as manifest keys."
  @spec prefix_paths(t(), String.t()) :: t()
  def prefix_paths(%__MODULE__{} = entry, prefix) do
    %{
      entry
      | file: prefix_path(entry.file, prefix),
        css: Enum.map(entry.css, &prefix_path(&1, prefix)),
        assets: Enum.map(entry.assets, &prefix_path(&1, prefix))
    }
  end

  defp prefix_path(nil, _prefix), do: nil
  defp prefix_path(path, prefix), do: Path.join(prefix, path)
end
