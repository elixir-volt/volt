defmodule Volt.JS.CommonJS do
  @moduledoc """
  Detects local CommonJS/UMD modules and converts them to ES modules for the dev server.

  Production builds hand CommonJS files to the bundler, which wraps them itself.
  The dev server serves each file as a native ES module, so a CommonJS file such
  as Phoenix's vendored `topbar.js` needs the same interop before a browser can
  `import topbar from "../vendor/topbar"`.
  """

  @esm_declarations [
    :import_declaration,
    :export_named_declaration,
    :export_default_declaration,
    :export_all_declaration
  ]

  @doc """
  Return whether the module at `path` is CommonJS/UMD rather than an ES module.

  `.cjs` and `.cts` files are CommonJS by extension. A `.js` file is CommonJS
  when it has no `import` or `export` declarations and uses `module.exports`,
  `exports`, or `require`.
  """
  @spec commonjs?(String.t(), String.t()) :: boolean()
  def commonjs?(source, path) do
    ext = Path.extname(path)

    cond do
      ext in Volt.JS.Extensions.cjs() -> true
      ext == ".js" -> commonjs_source?(source, Path.basename(path))
      true -> false
    end
  end

  defp commonjs_source?(source, filename) do
    case OXC.parse(source, filename) do
      {:ok, ast} -> not esm?(ast) and uses_commonjs?(ast)
      {:error, _} -> false
    end
  end

  @doc """
  Bundle the CommonJS file at `path` into an ES module whose default export is
  `module.exports`. Modules it requires are bundled along with it.

  ## Options

    * `:modules` — directories used to resolve bare `require` specifiers
    * `:module_types` — bundler module type overrides
  """
  @spec to_esm(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_esm(path, opts \\ []) do
    module_types = Keyword.get(opts, :module_types, %{})

    bundle_opts =
      [
        cwd: Path.dirname(path),
        format: :esm,
        conditions: Volt.JS.Resolution.browser_conditions(),
        modules: Keyword.get(opts, :modules, []),
        define: %{"process.env.NODE_ENV" => ~s("development")}
      ] ++ if(module_types != %{}, do: [module_types: module_types], else: [])

    case OXC.bundle(path, bundle_opts) do
      {:ok, %{code: code}} -> {:ok, code}
      {:ok, code} when is_binary(code) -> {:ok, code}
      {:error, _} = error -> error
    end
  end

  defp esm?(%{body: body}) when is_list(body) do
    Enum.any?(body, &(&1[:type] in @esm_declarations))
  end

  defp esm?(_ast), do: false

  defp uses_commonjs?(ast) do
    {_ast, found?} =
      OXC.postwalk(ast, false, fn
        node, false -> {node, commonjs_node?(node)}
        node, true -> {node, true}
      end)

    found?
  end

  defp commonjs_node?(node) when is_map(node) do
    Volt.JS.AST.member_expression?(node, "module", "exports") or
      exports_member?(node) or
      match?({:ok, _}, Volt.JS.AST.call_arguments(node, "require"))
  end

  defp commonjs_node?(_node), do: false

  defp exports_member?(%{
         type: :member_expression,
         object: %{type: :identifier, name: "exports"}
       }),
       do: true

  defp exports_member?(_node), do: false
end
