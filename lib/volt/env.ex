defmodule Volt.Env do
  @moduledoc """
  Load environment variables for client-side code.

  Reads `.env` files and exposes variables prefixed with `VOLT_` as
  compile-time replacements for `import.meta.env.*` expressions.

  ## Files loaded (in order, later overrides earlier)

    1. `.env`
    2. `.env.local`
    3. `.env.{mode}` (e.g. `.env.production`)
    4. `.env.{mode}.local`

  ## Usage in source code

      // app.ts
      console.log(import.meta.env.VOLT_API_URL)

  Becomes at build time:

      console.log("https://api.example.com")

  The special variables `import.meta.env.MODE`, `import.meta.env.DEV`,
  and `import.meta.env.PROD` are always available.
  """

  @prefix "VOLT_"

  @doc """
  Build a define map for compile-time replacement.

  Returns a map suitable for passing as `:define` to `OXC.bundle/2`.

  ## Options

    * `:mode` — build mode (default: `"production"`)
    * `:root` — project root for `.env` files (default: cwd)
    * `:env` — extra variables to inject (takes precedence over files)
  """
  @spec define(keyword()) :: %{String.t() => String.t()}
  def define(opts \\ []) do
    mode = Keyword.get(opts, :mode, "production")
    root = Keyword.get(opts, :root, File.cwd!())
    extra = Keyword.get(opts, :env, %{})

    vars =
      load_env_files(root, mode)
      |> Map.merge(extra)
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, @prefix) end)
      |> Map.new()

    base = %{
      "import.meta.env.MODE" => Jason.encode!(mode),
      "import.meta.env.DEV" => to_string(mode != "production"),
      "import.meta.env.PROD" => to_string(mode == "production")
    }

    env_defines =
      Map.new(vars, fn {key, value} ->
        {"import.meta.env.#{key}", Jason.encode!(value)}
      end)

    Map.merge(base, env_defines)
  end

  @doc """
  Load and merge `.env` files for the given mode.
  """
  @spec load_env_files(String.t(), String.t()) :: %{String.t() => String.t()}
  def load_env_files(root, mode) do
    [".env", ".env.local", ".env.#{mode}", ".env.#{mode}.local"]
    |> Enum.map(&Path.join(root, &1))
    |> Enum.filter(&File.regular?/1)
    |> Enum.reduce(%{}, fn path, acc ->
      Map.merge(acc, parse_env_file(path))
    end)
  end

  @doc false
  def parse_env_file(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      line = String.trim(line)

      cond do
        line == "" -> acc
        String.starts_with?(line, "#") -> acc
        true -> parse_env_line(line, acc)
      end
    end)
  end

  defp parse_env_line(line, acc) do
    line = String.trim_leading(line, "export ")

    case String.split(line, "=", parts: 2) do
      [key, value] ->
        key = String.trim(key)
        value = value |> String.trim() |> unquote_value()
        Map.put(acc, key, value)

      _ ->
        acc
    end
  end

  defp unquote_value(<<q, rest::binary>>) when q in [?", ?'] do
    case :binary.last(rest) do
      ^q -> binary_part(rest, 0, byte_size(rest) - 1)
      _ -> <<q, rest::binary>>
    end
  end

  defp unquote_value(value), do: value
end
