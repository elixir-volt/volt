defmodule Volt.CSS.Imports do
  @moduledoc "Resolves and inlines local and package CSS `@import` rules before bundling."

  @css_extensions [".css"]
  @css_conditions ["style", "import", "default"]

  @doc "Inline resolvable CSS imports from `source_path` using Volt package resolution options."
  @spec inline(String.t(), String.t() | nil, keyword()) :: {:ok, String.t()} | {:error, term()}
  def inline(css, nil, _opts), do: {:ok, css}

  def inline(css, source_path, opts) when is_binary(css) and is_binary(source_path) do
    do_inline(css, source_path, opts, MapSet.new([Path.expand(source_path)]))
  end

  defp do_inline(css, source_path, opts, seen) do
    case Vize.CSS.select(css, :dependencies, filename: source_path) do
      {:ok, dependencies} ->
        dependencies
        |> Enum.filter(&(&1[:kind] == :import))
        |> Enum.sort_by(& &1.start, :desc)
        |> Enum.reduce_while({:ok, css}, fn dependency, {:ok, acc} ->
          case inline_dependency(acc, dependency, source_path, opts, seen) do
            {:ok, next_css} -> {:cont, {:ok, next_css}}
            {:error, _} = error -> {:halt, error}
          end
        end)

      {:error, _} ->
        {:ok, css}
    end
  end

  defp inline_dependency(css, dependency, source_path, opts, seen) do
    with {:ok, resolved} <- resolve_import(dependency.url, source_path, opts),
         false <- MapSet.member?(seen, resolved),
         {:ok, imported_css} <- File.read(resolved),
         {:ok, imported_css} <-
           do_inline(imported_css, resolved, opts, MapSet.put(seen, resolved)),
         {:ok, {rule_start, rule_end}} <- import_rule_bounds(css, dependency) do
      {:ok, replace_range(css, rule_start, rule_end, imported_css <> "\n")}
    else
      true -> {:ok, css}
      :skip -> {:ok, css}
      {:error, _} = error -> error
    end
  end

  defp resolve_import(url, source_path, opts) do
    uri = URI.parse(url)

    cond do
      not is_binary(uri.path) or uri.path == "" ->
        :skip

      uri.scheme || uri.host || String.starts_with?(url, ["/", "#", "//"]) ->
        :skip

      NPM.Resolution.PackageResolver.relative?(uri.path) ->
        source_path
        |> Path.dirname()
        |> Path.join(uri.path)
        |> Path.expand()
        |> NPM.Resolution.PackageResolver.try_resolve(
          conditions: @css_conditions,
          extensions: @css_extensions
        )

      true ->
        resolve_bare_import(uri.path, opts)
    end
  end

  defp resolve_bare_import(specifier, opts) do
    dirs =
      opts
      |> Keyword.get(:resolve_dirs, [])
      |> then(fn dirs ->
        case Keyword.get(opts, :node_modules) do
          nil -> dirs
          node_modules -> [node_modules | dirs]
        end
      end)

    Enum.find_value(dirs, :skip, fn dir ->
      {package_name, _subpath} = NPM.Resolution.PackageResolver.split_specifier(specifier)
      package_dir = Path.join(dir, package_name)

      if File.dir?(package_dir) do
        case NPM.Resolution.PackageResolver.resolve_entry(package_dir,
               subpath: subpath_for(specifier),
               conditions: @css_conditions,
               extensions: @css_extensions
             ) do
          {:ok, _} = ok -> ok
          :error -> nil
        end
      end
    end)
  end

  defp subpath_for(specifier) do
    case NPM.Resolution.PackageResolver.split_specifier(specifier) do
      {_, nil} -> "."
      {_, subpath} -> subpath
    end
  end

  defp import_rule_bounds(css, %{start: start, end: finish}) do
    with {:ok, rule_start} <- last_import_before(css, start),
         {:ok, rule_end} <- next_semicolon_after(css, finish) do
      {:ok, {rule_start, rule_end}}
    end
  end

  defp last_import_before(css, start) do
    prefix = binary_part(css, 0, start)

    case :binary.matches(prefix, "@import") do
      [] -> {:error, :import_rule_not_found}
      matches -> {:ok, matches |> List.last() |> elem(0)}
    end
  end

  defp next_semicolon_after(css, finish) do
    rest = binary_part(css, finish, byte_size(css) - finish)

    case :binary.match(rest, ";") do
      {offset, 1} -> {:ok, finish + offset + 1}
      :nomatch -> {:error, :import_rule_not_terminated}
    end
  end

  defp replace_range(css, start, finish, replacement) do
    binary_part(css, 0, start) <> replacement <> binary_part(css, finish, byte_size(css) - finish)
  end
end
