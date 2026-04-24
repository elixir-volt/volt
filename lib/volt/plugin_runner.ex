defmodule Volt.PluginRunner do
  @moduledoc """
  Execute Volt plugin hooks.
  """

  @default_plugins [Volt.Plugin.Vue, Volt.Plugin.Svelte, Volt.Plugin.React]

  def plugins(plugins) do
    (@default_plugins ++ List.wrap(plugins))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&plugin_module/1)
  end

  @doc "Run extension hooks and return plugin-provided extensions for a kind."
  @spec extensions([module() | {module(), keyword()}], atom()) :: [String.t()]
  def extensions(plugins, kind) do
    plugins
    |> plugins()
    |> Enum.flat_map(fn plugin ->
      call_optional(plugin, :extensions, [kind], [])
    end)
    |> Enum.uniq()
  end

  @doc "Run resolve hooks. Returns `{:ok, path}`, `:skip`, or `nil`."
  @spec resolve([module() | {module(), keyword()}], String.t(), String.t() | nil) ::
          {:ok, String.t()} | :skip | nil
  def resolve(plugins, specifier, importer) do
    Enum.find_value(plugins(plugins), fn plugin ->
      call_optional(plugin, :resolve, [specifier, importer], nil)
    end)
  end

  @doc "Run load hooks. Returns `{:ok, code, content_type}`, `{:ok, code}`, or `nil`."
  @spec load([module() | {module(), keyword()}], String.t()) ::
          {:ok, String.t(), String.t()} | {:ok, String.t()} | nil
  def load(plugins, path) do
    Enum.find_value(plugins(plugins), fn plugin ->
      call_optional(plugin, :load, [path], nil)
    end)
  end

  @doc "Run compile hooks. Returns `{:ok, compiled}`, `{:error, term}`, or `nil`."
  @spec compile([module() | {module(), keyword()}], String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()} | nil
  def compile(plugins, path, source, opts) do
    Enum.find_value(plugins(plugins), fn plugin ->
      call_optional(plugin, :compile, [path, source, opts], nil)
    end)
  end

  @doc "Run import extraction hooks. Returns import metadata or `nil`."
  @spec extract_imports([module() | {module(), keyword()}], String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()} | nil
  def extract_imports(plugins, path, source, opts) do
    Enum.find_value(plugins(plugins), fn plugin ->
      call_optional(plugin, :extract_imports, [path, source, opts], nil)
    end)
  end

  @doc "Run transform hooks in sequence, piping code through each."
  @spec transform([module() | {module(), keyword()}], String.t(), String.t()) :: String.t()
  def transform(plugins, code, path) do
    Enum.reduce(plugins(plugins), code, fn plugin, acc ->
      case call_optional(plugin, :transform, [acc, path], nil) do
        {:ok, transformed} -> transformed
        nil -> acc
      end
    end)
  end

  @doc "Collect plugin-provided compile-time replacements for a build mode."
  @spec define([module() | {module(), keyword()}], String.t()) :: %{String.t() => String.t()}
  def define(plugins, mode) do
    Enum.reduce(plugins(plugins), %{}, fn plugin, acc ->
      Map.merge(acc, call_optional(plugin, :define, [mode], %{}))
    end)
  end

  @doc "Resolve a plugin-provided canonical prebundle specifier."
  @spec prebundle_alias([module() | {module(), keyword()}], String.t()) :: String.t()
  def prebundle_alias(plugins, specifier) do
    Enum.find_value(plugins(plugins), specifier, fn plugin ->
      call_optional(plugin, :prebundle_alias, [specifier], nil)
    end)
  end

  @doc "Resolve a plugin-provided generated prebundle entry."
  @spec prebundle_entry([module() | {module(), keyword()}], String.t()) ::
          {:source, String.t(), String.t()} | {:proxy, String.t(), keyword()} | nil
  def prebundle_entry(plugins, specifier) do
    Enum.find_value(plugins(plugins), fn plugin ->
      call_optional(plugin, :prebundle_entry, [specifier], nil)
    end)
  end

  @doc "Run render_chunk hooks in sequence."
  @spec render_chunk([module() | {module(), keyword()}], String.t(), map()) :: String.t()
  def render_chunk(plugins, code, chunk_info) do
    Enum.reduce(plugins(plugins), code, fn plugin, acc ->
      case call_optional(plugin, :render_chunk, [acc, chunk_info], nil) do
        {:ok, transformed} -> transformed
        nil -> acc
      end
    end)
  end

  defp call_optional(plugin, fun, args, default) do
    module = plugin_module(plugin)
    opts = plugin_opts(plugin)

    cond do
      Code.ensure_loaded?(module) and function_exported?(module, fun, length(args) + 1) ->
        apply(module, fun, args ++ [opts])

      Code.ensure_loaded?(module) and function_exported?(module, fun, length(args)) ->
        apply(module, fun, args)

      true ->
        default
    end
  end

  defp plugin_module({module, _opts}), do: module
  defp plugin_module(module), do: module

  defp plugin_opts({_module, opts}), do: opts
  defp plugin_opts(_module), do: []
end
