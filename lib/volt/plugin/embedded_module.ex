defmodule Volt.Plugin.EmbeddedModule do
  @moduledoc """
  A module embedded in a source file owned by a Volt plugin.

  Embedded modules model single-file-component subresources such as `<script>`
  and `<style>` blocks. They are addressed as query modules derived from the
  real parent file instead of opaque synthetic ids, which preserves source-file
  identity for resolution, watching, and diagnostics.
  """

  @marker "volt-embedded"
  @marker_value "1"

  @type kind :: :script | :style | :custom

  defmodule ID do
    @moduledoc "Parsed identity for an embedded query-module id."

    @type t :: %__MODULE__{
            parent: String.t(),
            type: Volt.Plugin.EmbeddedModule.kind(),
            index: non_neg_integer()
          }

    defstruct [:parent, :type, :index]
  end

  @type t :: %__MODULE__{
          type: kind(),
          index: non_neg_integer() | nil,
          extension: String.t(),
          source: String.t(),
          content_type: String.t() | nil
        }

  defstruct type: :script,
            index: nil,
            extension: ".js",
            source: "",
            content_type: nil

  @doc "Build the internal query-module id for an embedded module under a parent file."
  @spec id(String.t(), t()) :: String.t()
  def id(parent, %__MODULE__{} = module) do
    Volt.URL.append_query(parent, query(module))
  end

  @doc "Build an import specifier for an embedded module from its parent module."
  @spec specifier(String.t(), t()) :: String.t()
  def specifier(parent, %__MODULE__{} = module) do
    Volt.URL.append_query(Volt.Path.relative_import(parent, parent), query(module))
  end

  @doc "Parse an embedded query-module id."
  @spec parse_id(String.t()) :: {:ok, ID.t()} | :error
  def parse_id(id) do
    with {parent, query} when query != "" <- Volt.URL.split_query(id),
         %{@marker => @marker_value, "type" => type, "index" => index} <- URI.decode_query(query),
         {:ok, type} <- parse_type(type),
         {index, ""} <- Integer.parse(index),
         true <- index >= 0 do
      {:ok, %ID{parent: parent, type: type, index: index}}
    else
      _ -> :error
    end
  end

  @doc "Return true when an id addresses an embedded module."
  @spec id?(String.t()) :: boolean()
  def id?(id), do: match?({:ok, _}, parse_id(id))

  @doc "Return the real parent file for ids that address embedded modules."
  @spec parent_path(String.t()) :: String.t()
  def parent_path(id) do
    case parse_id(id) do
      {:ok, %ID{parent: parent}} -> parent
      :error -> id |> Volt.URL.split_query() |> elem(0)
    end
  end

  @doc "Return a compiler-friendly filename for the embedded module."
  @spec filename(String.t(), t() | nil) :: String.t()
  def filename(parent, %__MODULE__{} = module) do
    parent
    |> Path.basename()
    |> Kernel.<>(".#{module.type}#{module.index}#{module.extension}")
  end

  def filename(path, nil), do: path |> parent_path() |> Path.basename()

  @doc "Content type inferred from an embedded module kind."
  @spec content_type(t()) :: String.t()
  def content_type(%__MODULE__{content_type: content_type}) when is_binary(content_type),
    do: content_type

  def content_type(%__MODULE__{type: :style}), do: Volt.MIME.css()
  def content_type(%__MODULE__{type: _}), do: Volt.MIME.javascript()

  @doc "Normalize a list of embedded modules and assign indexes where omitted."
  @spec normalize_all([term()]) :: [t()]
  def normalize_all(modules) do
    modules
    |> Enum.with_index()
    |> Enum.map(fn {module, index} -> normalize(module, index) end)
  end

  @doc "Normalize legacy tuple modules or maps into embedded module structs."
  @spec normalize(term(), non_neg_integer()) :: t()
  def normalize(%__MODULE__{index: nil} = module, index), do: %{module | index: index}
  def normalize(%__MODULE__{} = module, _index), do: module

  def normalize({extension, source}, index) when is_binary(extension) and is_binary(source) do
    type = if extension in Volt.JS.Extensions.css(), do: :style, else: :script

    %__MODULE__{
      type: type,
      index: index,
      extension: extension,
      source: source,
      content_type: inferred_content_type(type)
    }
  end

  defp query(%__MODULE__{index: index} = module) when is_integer(index) and index >= 0 do
    URI.encode_query(%{
      @marker => @marker_value,
      "type" => Atom.to_string(module.type),
      "index" => Integer.to_string(index)
    })
  end

  defp inferred_content_type(:style), do: Volt.MIME.css()
  defp inferred_content_type(_), do: Volt.MIME.javascript()

  defp parse_type("script"), do: {:ok, :script}
  defp parse_type("style"), do: {:ok, :style}
  defp parse_type("custom"), do: {:ok, :custom}
  defp parse_type(_), do: :error
end
