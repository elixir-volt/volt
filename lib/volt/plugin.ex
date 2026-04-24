defmodule Volt.Plugin do
  @moduledoc """
  Behaviour for Volt build plugins.

  Plugins can participate in resolution, loading, compilation, import
  extraction, and final chunk rendering. All callbacks except `name/0` are
  optional.

  Plugins may be configured as modules or `{module, opts}` tuples. When a
  plugin defines a callback with one extra arity, Volt passes the tuple opts as
  the final argument.
  """

  @type compiled :: %{
          code: String.t(),
          sourcemap: String.t() | nil,
          css: String.t() | nil,
          hashes: map() | nil
        }

  @doc "Plugin name for identification and error messages."
  @callback name() :: String.t()

  @doc "Return extensions owned by this plugin for `:compile`, `:resolve`, `:watch`, or `:scan`."
  @callback extensions(kind :: atom()) :: [String.t()]

  @doc "Resolve an import specifier to a file path, `:skip`, or pass with `nil`."
  @callback resolve(specifier :: String.t(), importer :: String.t() | nil) ::
              {:ok, String.t()} | :skip | nil

  @doc "Load content for a resolved module path."
  @callback load(path :: String.t()) ::
              {:ok, String.t(), String.t()} | {:ok, String.t()} | nil

  @doc "Compile a source file into browser-ready JavaScript plus optional CSS."
  @callback compile(path :: String.t(), source :: String.t(), opts :: keyword()) ::
              {:ok, compiled()} | {:error, term()} | nil

  @doc "Extract static/dynamic imports and worker specifiers from a source file."
  @callback extract_imports(path :: String.t(), source :: String.t(), opts :: keyword()) ::
              {:ok, %{imports: [{:static | :dynamic, String.t()}], workers: [String.t()]}}
              | {:error, term()}
              | nil

  @doc "Transform compiled JavaScript before serving or bundling."
  @callback transform(code :: String.t(), path :: String.t()) :: {:ok, String.t()} | nil

  @doc "Return compile-time replacements for a build mode."
  @callback define(mode :: String.t()) :: %{String.t() => String.t()}

  @doc "Return the canonical prebundle specifier to use for an import, or pass with `nil`."
  @callback prebundle_alias(specifier :: String.t()) :: String.t() | nil

  @doc "Return a generated prebundle entry for a canonical specifier, or pass with `nil`."
  @callback prebundle_entry(specifier :: String.t()) ::
              {:source, filename :: String.t(), source :: String.t()}
              | {:proxy, filename :: String.t(), keyword()}
              | nil

  @doc "Transform a final output chunk before writing."
  @callback render_chunk(code :: String.t(), chunk_info :: map()) :: {:ok, String.t()} | nil

  @optional_callbacks extensions: 1,
                      resolve: 2,
                      load: 1,
                      compile: 3,
                      extract_imports: 3,
                      transform: 2,
                      define: 1,
                      prebundle_alias: 1,
                      prebundle_entry: 1,
                      render_chunk: 2
end
