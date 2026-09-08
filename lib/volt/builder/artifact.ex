defmodule Volt.Builder.Artifact do
  @moduledoc false

  @enforce_keys [:file, :content]
  defstruct [:file, :content]

  @type t :: %__MODULE__{file: String.t(), content: binary()}

  @spec asset(String.t(), binary()) :: t()
  def asset(source_path, content) do
    ext = Path.extname(source_path)
    name = Path.basename(source_path, ext)
    hash = Volt.Format.content_hash(content)
    %__MODULE__{file: "#{name}-#{hash}#{ext}", content: content}
  end

  @spec javascript(String.t(), binary(), binary() | nil, keyword()) :: [t()]
  def javascript(filename, code, sourcemap, opts \\ []) do
    code =
      if sourcemap && !Keyword.get(opts, :hidden, false) do
        code <> "\n//# sourceMappingURL=#{filename}.map\n"
      else
        code
      end

    script = %__MODULE__{file: filename, content: code}

    case sourcemap do
      nil -> [script]
      map -> [script, %__MODULE__{file: "#{filename}.map", content: map}]
    end
  end
end
