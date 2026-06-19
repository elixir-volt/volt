defmodule Volt.JS.Transforms.ImportMetaEnv do
  @moduledoc "Injects `import.meta.env` values into JavaScript modules when referenced."

  @prefix "import.meta.env."

  @spec inject(String.t(), String.t(), %{String.t() => String.t()}) ::
          {:ok, String.t()} | {:error, term()}
  def inject(source, _filename, define) when define in [%{}, nil], do: {:ok, source}

  def inject(source, filename, define) do
    env = env_from_define(define)

    if map_size(env) == 0 do
      {:ok, source}
    else
      with {:ok, refs} <- OXC.select(source, filename, :import_meta_env) do
        if refs == [] do
          {:ok, source}
        else
          {:ok, env_assignment(env) <> source}
        end
      end
    end
  end

  defp env_from_define(define) do
    define
    |> Enum.filter(fn {key, _value} -> String.starts_with?(key, @prefix) end)
    |> Map.new(fn {key, value} -> {String.replace_prefix(key, @prefix, ""), value} end)
  end

  defp env_assignment(env) do
    properties =
      env
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map(fn {key, value} -> [Jason.encode!(key), ": ", value] end)
      |> Enum.intersperse(", ")

    IO.iodata_to_binary(["import.meta.env = { ", properties, " };\n"])
  end
end
