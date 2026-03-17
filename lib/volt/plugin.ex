defmodule Volt.Plugin do
  @moduledoc """
  Behaviour for Volt build plugins.

  Plugins hook into the compilation pipeline at four stages:

    1. **resolve** — remap import specifiers before file lookup
    2. **load** — provide virtual module content for a specifier
    3. **transform** — modify compiled output before it's served/bundled
    4. **render_chunk** — modify final bundled chunks before writing

  Each callback is optional. Return `nil` or `:pass` to skip.

  ## Example

      defmodule MyApp.SvgPlugin do
        @behaviour Volt.Plugin

        @impl true
        def name, do: "svg"

        @impl true
        def resolve(specifier, _importer) do
          if String.ends_with?(specifier, ".svg") do
            {:ok, specifier}
          end
        end

        @impl true
        def load(path) do
          if String.ends_with?(path, ".svg") do
            svg = File.read!(path)
            {:ok, "export default " <> Jason.encode!(svg), "application/javascript"}
          end
        end

        @impl true
        def transform(_code, _path), do: nil

        @impl true
        def render_chunk(_code, _chunk_info), do: nil
      end
  """

  @doc "Plugin name for identification and error messages."
  @callback name() :: String.t()

  @doc """
  Resolve an import specifier to a file path or virtual module ID.

  Return `{:ok, resolved_path}` to handle, `nil` to pass to the next plugin.
  """
  @callback resolve(specifier :: String.t(), importer :: String.t() | nil) ::
              {:ok, String.t()} | nil

  @doc """
  Load content for a resolved module path.

  Return `{:ok, code, content_type}` to provide content,
  `{:ok, code}` (defaults to JS), or `nil` to pass.
  """
  @callback load(path :: String.t()) ::
              {:ok, String.t(), String.t()} | {:ok, String.t()} | nil

  @doc """
  Transform compiled code.

  Return `{:ok, code}` with modified code, or `nil` to pass.
  """
  @callback transform(code :: String.t(), path :: String.t()) ::
              {:ok, String.t()} | nil

  @doc """
  Transform a final output chunk before writing.

  Return `{:ok, code}` with modified code, or `nil` to pass.
  """
  @callback render_chunk(code :: String.t(), chunk_info :: map()) ::
              {:ok, String.t()} | nil

  @optional_callbacks resolve: 2, load: 1, transform: 2, render_chunk: 2
end
