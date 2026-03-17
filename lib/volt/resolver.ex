defmodule Volt.Resolver do
  @moduledoc """
  Import specifier resolution with alias support.

  Aliases map import prefixes to filesystem paths:

      config :volt, :aliases, %{
        "@" => "assets/src",
        "@components" => "assets/src/components"
      }

  When `import Foo from '@/utils/foo'` is encountered, the `@/` prefix
  is replaced with the configured path before resolution.
  """

  @doc """
  Resolve an import specifier using the given aliases.

  Returns `{:ok, resolved_specifier}` if an alias matched,
  or `:pass` if no alias applies.
  """
  @spec resolve(String.t(), %{String.t() => String.t()}) :: {:ok, String.t()} | :pass
  def resolve(_specifier, aliases) when map_size(aliases) == 0, do: :pass

  def resolve(specifier, aliases) do
    aliases
    |> Enum.sort_by(fn {k, _} -> -byte_size(k) end)
    |> Enum.find_value(:pass, fn {prefix, target} ->
      match_alias(specifier, prefix, target)
    end)
  end

  defp match_alias(specifier, prefix, target) do
    prefix_with_slash = prefix <> "/"

    cond do
      specifier == prefix ->
        {:ok, Path.expand(target)}

      String.starts_with?(specifier, prefix_with_slash) ->
        rest = String.trim_leading(specifier, prefix_with_slash)
        {:ok, Path.expand(Path.join(target, rest))}

      true ->
        nil
    end
  end
end
