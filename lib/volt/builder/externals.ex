defmodule Volt.Builder.Externals do
  @moduledoc false

  @doc """
  Scan compiled JS files for imports from external specifiers.

  Returns a map of `specifier => [imported_names]` where each name is
  `{:named, name}`, `{:default, name}`, or `{:namespace, name}`.
  """
  def collect_imports(js_files, external_set) do
    js_files
    |> Enum.reduce(%{}, fn {_label, code}, acc ->
      case extract_external_imports(code, external_set) do
        [] -> acc
        imports -> merge_imports(acc, imports)
      end
    end)
  end

  @doc """
  Generate a JS preamble that destructures external globals.

      %{"vue" => [named: "ref", named: "h"], "reka-ui" => [default: "RekaButton"]}

  With globals `%{"vue" => "Vue", "reka-ui" => "RekaUi"}` produces:

      const { ref, h } = Vue;
      const RekaButton = RekaUi.default;
  """
  def generate_preamble(external_imports, external_globals) do
    external_imports
    |> Enum.sort_by(fn {spec, _} -> spec end)
    |> Enum.map_join("\n", fn {specifier, names} ->
      global = Map.get(external_globals, specifier, derive_global(specifier))
      emit_global_access(global, names)
    end)
    |> case do
      "" -> ""
      preamble -> preamble <> "\n"
    end
  end

  defp extract_external_imports(code, external_set) do
    case OXC.parse(code, "module.js") do
      {:ok, ast} ->
        {_ast, imports} =
          OXC.postwalk(ast, [], fn
            %{type: "ImportDeclaration", source: %{value: spec}, specifiers: specifiers} = node, acc ->
              if MapSet.member?(external_set, spec) do
                names = Enum.map(specifiers, &classify_specifier/1)
                {node, [{spec, names} | acc]}
              else
                {node, acc}
              end

            node, acc ->
              {node, acc}
          end)

        Enum.reverse(imports)

      {:error, _} ->
        []
    end
  end

  defp classify_specifier(%{type: "ImportSpecifier", imported: %{name: name}, local: %{name: local}}) do
    if name == local, do: {:named, name}, else: {:named, name, local}
  end

  defp classify_specifier(%{type: "ImportDefaultSpecifier", local: %{name: name}}) do
    {:default, name}
  end

  defp classify_specifier(%{type: "ImportNamespaceSpecifier", local: %{name: name}}) do
    {:namespace, name}
  end

  defp classify_specifier(_), do: nil

  defp merge_imports(acc, imports) do
    Enum.reduce(imports, acc, fn {spec, names}, a ->
      existing = Map.get(a, spec, [])
      merged = (existing ++ names) |> Enum.uniq()
      Map.put(a, spec, merged)
    end)
  end

  defp emit_global_access(global, names) do
    {named, others} =
      Enum.split_with(names, fn
        {:named, _} -> true
        {:named, _, _} -> true
        _ -> false
      end)

    parts = []

    parts =
      if named != [] do
        destructured =
          Enum.map_join(named, ", ", fn
            {:named, name} -> name
            {:named, name, local} -> "#{name}: #{local}"
          end)

        [~s(const { #{destructured} } = #{global};) | parts]
      else
        parts
      end

    parts =
      Enum.reduce(others, parts, fn
        {:default, name}, p -> [~s(const #{name} = #{global}.default;) | p]
        {:namespace, name}, p -> [~s(const #{name} = #{global};) | p]
        nil, p -> p
      end)

    parts |> Enum.reverse() |> Enum.join("\n")
  end

  defp derive_global(specifier), do: Volt.Builder.derive_global_name(specifier)
end
