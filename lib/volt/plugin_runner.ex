defmodule Volt.PluginRunner do
  @moduledoc """
  Execute plugin hooks in order, short-circuiting on first match.
  """

  @doc "Run resolve hooks. Returns `{:ok, path}` or `nil`."
  @spec resolve([module()], String.t(), String.t() | nil) :: {:ok, String.t()} | nil
  def resolve(plugins, specifier, importer) do
    Enum.find_value(plugins, fn plugin ->
      if function_exported?(plugin, :resolve, 2) do
        plugin.resolve(specifier, importer)
      end
    end)
  end

  @doc "Run load hooks. Returns `{:ok, code, content_type}` or `nil`."
  @spec load([module()], String.t()) :: {:ok, String.t(), String.t()} | {:ok, String.t()} | nil
  def load(plugins, path) do
    Enum.find_value(plugins, fn plugin ->
      if function_exported?(plugin, :load, 1) do
        plugin.load(path)
      end
    end)
  end

  @doc "Run transform hooks in sequence, piping code through each."
  @spec transform([module()], String.t(), String.t()) :: String.t()
  def transform(plugins, code, path) do
    Enum.reduce(plugins, code, fn plugin, acc ->
      if function_exported?(plugin, :transform, 2) do
        case plugin.transform(acc, path) do
          {:ok, transformed} -> transformed
          nil -> acc
        end
      else
        acc
      end
    end)
  end

  @doc "Run render_chunk hooks in sequence."
  @spec render_chunk([module()], String.t(), map()) :: String.t()
  def render_chunk(plugins, code, chunk_info) do
    Enum.reduce(plugins, code, fn plugin, acc ->
      if function_exported?(plugin, :render_chunk, 2) do
        case plugin.render_chunk(acc, chunk_info) do
          {:ok, transformed} -> transformed
          nil -> acc
        end
      else
        acc
      end
    end)
  end
end
