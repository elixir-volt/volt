defmodule Volt.Test.Imports do
  @moduledoc """
  Handles Volt test virtual imports.

  The current runner exposes the `volt:test` API as globals inside the
  QuickBEAM runtime. This module removes imports from `volt:test` and
  `volt:test/browser` before normal Volt compilation so users can still write
  idiomatic test files:

      import { test, expect } from "volt:test"

      test("works", () => {
        expect(1 + 1).toBe(2)
      })

  The rewrite is AST-backed and only removes actual import declarations whose
  source literal is a Volt test virtual module.
  """

  @virtual_modules MapSet.new(["volt:test", "volt:test/browser"])

  @spec strip(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def strip(source, filename) do
    case OXC.parse(source, filename) do
      {:ok, ast} -> {:ok, Volt.JS.Patch.apply(source, patches(ast))}
      {:error, _} = error -> error
    end
  end

  @spec strip!(String.t(), String.t()) :: String.t()
  def strip!(source, filename) do
    case strip(source, filename) do
      {:ok, source} -> source
      {:error, errors} -> raise "Volt test import rewrite error: #{inspect(errors)}"
    end
  end

  defp patches(ast) do
    {_ast, patches} =
      OXC.postwalk(ast, [], fn
        %{type: :import_declaration, source: %{value: specifier}} = node, patches
        when is_binary(specifier) ->
          if MapSet.member?(@virtual_modules, specifier) do
            {node, [Volt.JS.Patch.new(node.start, node.end, "") | patches]}
          else
            {node, patches}
          end

        node, patches ->
          {node, patches}
      end)

    patches
  end
end
