defmodule Volt.Plugin do
  @moduledoc """
  Behaviour for Volt build plugins.

  Plugins can participate in resolution, loading, compilation, import
  extraction, and final chunk rendering. All callbacks except `name/0` are
  optional.

  Plugins may be configured as modules or `{module, opts}` tuples. When a
  plugin defines a callback with one extra arity, Volt passes the tuple opts as
  the final argument.

  Plugins can opt into Vite-style ordering with `enforce/0` or `enforce/1`:
  `:pre` plugins run before normal plugins, and `:post` plugins run after them.
  """

  @type compiled :: Volt.Pipeline.Result.t()

  @doc "Plugin name for identification and error messages."
  @callback name() :: String.t()

  @doc "Return `:pre`, `:post`, or `nil` to control plugin ordering."
  @callback enforce() :: :pre | :post | nil

  @doc "Return extensions owned by this plugin for `:compile`, `:resolve`, `:watch`, or `:scan`."
  @callback extensions(kind :: atom()) :: [String.t()]

  @doc "Resolve an import or build-entry specifier to a file path, virtual module id, `:skip`, or pass with `nil`."
  @callback resolve(specifier :: String.t(), importer :: String.t() | nil) ::
              {:ok, String.t()} | :skip | nil

  @doc "Load content for a resolved module path."
  @callback load(path :: String.t()) ::
              {:ok, String.t(), String.t()} | {:ok, String.t()} | nil

  @doc "Compile a source file into browser-ready JavaScript plus optional CSS."
  @callback compile(path :: String.t(), source :: String.t(), opts :: keyword()) ::
              {:ok, compiled()} | {:error, term()} | nil

  @doc """
  Extract dependency metadata from source handled by this plugin.

  Use this when a source format can contain imports that are not visible to
  Volt's normal JavaScript parser before plugin processing, such as component
  files or custom markup formats. Return `nil` to let Volt use the default
  JavaScript import extractor.
  """
  @callback extract_imports(path :: String.t(), source :: String.t(), opts :: keyword()) ::
              {:ok, Volt.JS.ImportExtractor.Result.t()} | {:error, term()} | nil

  @doc "Return virtual JavaScript-like modules embedded in a plugin-owned source file."
  @callback embedded_modules(path :: String.t(), source :: String.t(), opts :: keyword()) ::
              [{extension :: String.t(), source :: String.t()}] | nil

  @doc "Transform compiled JavaScript before serving or bundling."
  @callback transform(code :: String.t(), path :: String.t()) :: {:ok, String.t()} | nil

  @doc "Return compile-time replacements for a build mode."
  @callback define(mode :: String.t()) :: %{String.t() => String.t()}

  @doc """
  Return the canonical dev prebundle specifier for an import.

  Use this advanced framework-integration hook when several package entrypoints
  should share one dev vendor module. Return `nil` to leave the specifier
  unchanged.

  This is Volt-specific. Vite framework plugins achieve similar results through
  dependency optimization, resolution, and virtual modules rather than a direct
  hook with this name.
  """
  @callback prebundle_alias(specifier :: String.t()) :: String.t() | nil

  @type prebundle_import :: Volt.JS.PrebundleEntry.Import.t()
  @type prebundle_export :: Volt.JS.PrebundleEntry.Export.t()

  @doc """
  Return a generated dev prebundle entry for a canonical specifier.

  Use this advanced framework-integration hook when a framework needs a
  synthetic vendor module that re-exports multiple package entrypoints or adapts
  package exports for browser dev mode. Return `nil` to let Volt generate a
  normal package prebundle.

  This hook affects dev dependency prebundling only; production output is built
  from the application module graph.
  """
  @callback prebundle_entry(specifier :: String.t()) ::
              {:source, filename :: String.t(), source :: String.t()}
              | {:proxy, filename :: String.t(),
                 imports: [prebundle_import()], exports: [prebundle_export()]}
              | nil

  @doc "Transform a final output chunk before writing."
  @callback render_chunk(code :: String.t(), chunk_info :: map()) :: {:ok, String.t()} | nil

  @optional_callbacks enforce: 0,
                      extensions: 1,
                      resolve: 2,
                      load: 1,
                      compile: 3,
                      extract_imports: 3,
                      embedded_modules: 3,
                      transform: 2,
                      define: 1,
                      prebundle_alias: 1,
                      prebundle_entry: 1,
                      render_chunk: 2
end
