defmodule Volt.Priv do
  @moduledoc """
  Accesses browser support JavaScript and other runtime files from an OTP application's `priv` directory.

  `priv` is the OTP convention for application-specific runtime files. Volt uses this
  module for its own bundled browser support code, and plugin authors can use it to
  keep JavaScript and TypeScript in their application instead of embedding source in
  Elixir strings.

  The source may be either an OTP application atom or an `{app, root}` tuple. The
  tuple form keeps repeated calls concise when several files live under the same
  `priv` subdirectory:

      assets = {:my_app, "islands"}

      Volt.Priv.path(assets, "runtime.ts")
      Volt.Priv.read!(assets, "runtime.ts")
      Volt.Priv.js!(assets, "runtime.ts")
      Volt.Priv.js!(assets, "entry.ts", id: "counter", props: %{count: 1})

  `js!/3` binds `$placeholder` JavaScript literals with OXC before emitting browser
  JavaScript. That keeps templates valid TypeScript or JavaScript files instead of
  requiring EEx for ordinary data injection.
  """

  @type source :: atom() | {atom(), String.t()}
  @type bindings :: keyword() | map()

  @doc "Returns the absolute path to a file under an OTP application's `priv` directory."
  @spec path(source(), String.t()) :: String.t()
  def path({app, root}, relative) when is_atom(app) and is_binary(root) and is_binary(relative) do
    Application.app_dir(
      app,
      Path.join(["priv", clean_relative!(root), clean_relative!(relative)])
    )
  end

  def path(app, relative) when is_atom(app) and is_binary(relative) do
    Application.app_dir(app, Path.join("priv", clean_relative!(relative)))
  end

  @doc "Reads a file from an OTP application's `priv` directory."
  @spec read!(source(), String.t()) :: String.t()
  def read!(source, relative) when is_binary(relative) do
    source
    |> path(relative)
    |> File.read!()
  end

  @doc """
  Emits browser JavaScript for a support file stored under `priv`.

  TypeScript and JavaScript files are both accepted. When bindings are provided, the
  source is parsed and `$placeholder` literals are replaced with JSON-compatible
  JavaScript literals using `OXC.bind/2` before the result is emitted.

  Options:

    * `:rewrite_specifiers` - a map or keyword list of import specifiers to rewrite
      after code generation.
  """
  @spec js!(source(), String.t()) :: String.t()
  @spec js!(source(), String.t(), bindings()) :: String.t()
  @spec js!(source(), String.t(), bindings(), keyword()) :: String.t()
  def js!(source, relative, bindings \\ [], opts \\ []) when is_binary(relative) do
    source
    |> js_source(relative, bindings)
    |> rewrite_specifiers(opts[:rewrite_specifiers], relative)
  end

  defp js_source(source, relative, bindings) when bindings == [] or bindings == %{} do
    key = {__MODULE__, :js, source, relative}

    case :persistent_term.get(key, nil) do
      nil ->
        code = source |> read!(relative) |> compile(relative)
        :persistent_term.put(key, code)
        code

      code ->
        code
    end
  end

  defp js_source(source, relative, bindings) do
    source
    |> template_ast!(relative)
    |> OXC.bind(literal_bindings(bindings))
    |> OXC.codegen!()
    |> compile(relative)
  end

  defp template_ast!(source, relative) do
    key = {__MODULE__, :template_ast, source, relative}

    case :persistent_term.get(key, nil) do
      nil ->
        ast = source |> read!(relative) |> OXC.parse!(relative)
        :persistent_term.put(key, ast)
        ast

      ast ->
        ast
    end
  end

  defp literal_bindings(bindings) do
    Enum.map(bindings, fn {key, value} -> {key, {:literal, value}} end)
  end

  defp rewrite_specifiers(code, nil, _filename), do: code
  defp rewrite_specifiers(code, [], _filename), do: code

  defp rewrite_specifiers(code, rewrites, filename) do
    rewrites = Map.new(rewrites)

    case OXC.rewrite_specifiers(code, filename, fn specifier ->
           case rewrites do
             %{^specifier => replacement} -> {:rewrite, replacement}
             _ -> :keep
           end
         end) do
      {:ok, rewritten} -> rewritten
      {:error, _errors} -> code
    end
  end

  # OXC.transform returns a plain string with sourcemap: false,
  # or %{code: string, sourcemap: string} with sourcemap: true.
  defp compile(source, filename) do
    case OXC.transform(source, filename, sourcemap: false) do
      {:ok, code} when is_binary(code) -> code
      {:ok, %{code: code}} -> code
      _ -> source
    end
  end

  defp clean_relative!(path) do
    cond do
      Path.type(path) == :absolute ->
        raise ArgumentError, "priv paths must be relative, got: #{inspect(path)}"

      path |> Path.split() |> Enum.member?("..") ->
        raise ArgumentError, "priv paths cannot contain .. segments, got: #{inspect(path)}"

      true ->
        path
    end
  end
end
