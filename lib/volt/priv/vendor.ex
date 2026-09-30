defmodule Volt.Priv.Vendor do
  @moduledoc """
  Vendors npm packages for browser code kept under `priv`.

  List the packages in a `package.json` beside the sources, pinned to exact
  versions, and commit it with the `npm.lock` that vendoring writes:

  ```json
  {"private": true, "dependencies": {"lit-html": "3.3.3"}}
  ```

  `mix volt.priv.vendor priv/ts` installs the locked versions and writes only the
  files the sources reach to `node_modules` beside them: the browser build of every
  imported module, the type declarations behind it, and each package's
  `package.json` and license. Keep that directory out of git and vendor before
  publishing, so the files ship in the Hex package and nothing is installed at
  runtime.

  `Volt.Priv.bundle!/3` resolves imports such as `import { html } from 'lit-html'`
  from there, and vendors on first use when the directory is missing, as in a git
  checkout.
  """

  alias NPM.Resolution.PackageResolver

  @source_extensions ~w(.ts .tsx .mts .js .jsx .mjs)
  @type_conditions ["types", "import", "default"]

  @doc """
  Vendors the packages that `dir/package.json` lists into `dir/node_modules`.

  ## Options

    * `:update` — resolve the versions again instead of using `dir/npm.lock`
  """
  @spec run!(Path.t(), keyword()) :: [Path.t()]
  def run!(dir, opts \\ []) do
    with_install(dir, opts, fn install_dir, files ->
      node_modules = Path.join(dir, "node_modules")
      File.rm_rf!(node_modules)

      for file <- files do
        target = Path.join(node_modules, file)
        File.mkdir_p!(Path.dirname(target))
        File.cp!(Path.join([install_dir, "node_modules", file]), target)
      end

      File.cp!(Path.join(install_dir, "npm.lock"), Path.join(dir, "npm.lock"))
      files
    end)
  end

  defp with_install(dir, opts, fun) do
    packages = dir |> Path.join("package.json") |> File.read!() |> Jason.decode!()
    packages = Map.get(packages, "dependencies", %{})
    lockfile = Path.join(dir, "npm.lock")

    install_dir =
      Path.join(System.tmp_dir!(), "volt-vendor-#{System.unique_integer([:positive])}")

    try do
      Volt.JS.Runtime.Installer.install!(packages,
        install_dir: install_dir,
        lockfile:
          if(File.regular?(lockfile) and not Keyword.get(opts, :update, false), do: lockfile)
      )

      fun.(install_dir, reachable(dir, packages, Path.join(install_dir, "node_modules")))
    after
      File.rm_rf!(install_dir)
    end
  end

  @doc false
  # The files the sources in `dir` reach in `node_modules`, relative to it.
  @spec reachable(Path.t(), map(), Path.t()) :: [Path.t()]
  def reachable(dir, packages, node_modules) do
    roots =
      for source <- sources(dir),
          specifier <- imports(source),
          Map.has_key?(packages, package_name(specifier)),
          kind <- [:js, :types],
          do: {kind, specifier, node_modules}

    roots
    |> walk(MapSet.new())
    |> Enum.flat_map(&[&1 | package_files(&1, node_modules)])
    |> Enum.uniq()
    |> Enum.map(&Path.relative_to(&1, node_modules))
    |> Enum.sort()
  end

  defp walk([], seen), do: seen

  defp walk([{kind, specifier, from} | rest], seen) do
    case resolve(kind, specifier, from) do
      {:ok, path} ->
        if MapSet.member?(seen, path) do
          walk(rest, seen)
        else
          next = for import <- imports(path), do: {kind, import, Path.dirname(path)}
          walk(next ++ rest, MapSet.put(seen, path))
        end

      :error ->
        walk(rest, seen)
    end
  end

  defp resolve(:js, specifier, from) do
    specifier
    |> PackageResolver.resolve(from,
      conditions: Volt.JS.Resolution.browser_conditions(),
      extensions: Volt.JS.Extensions.node_resolvable()
    )
    |> file_result()
  end

  # TypeScript's own lookup: a `types` export or a declaration beside the module,
  # the package's `types` field, then the same path under `@types`.
  defp resolve(:types, specifier, from) do
    with :error <- declaration(specifier, from),
         :error <- package_types(specifier, from),
         false <- relative?(specifier) or String.starts_with?(specifier, "@types/") do
      resolve(:types, types_specifier(specifier), from)
    else
      true -> :error
      found -> found
    end
  end

  # Declarations drop the module extension: `lib/index.js` is typed by `lib/index.d.ts`.
  defp declaration(specifier, from) do
    Enum.find_value([specifier, Path.rootname(specifier, Path.extname(specifier))], :error, fn
      specifier ->
        with {:ok, path} <-
               specifier
               |> PackageResolver.resolve(from,
                 conditions: @type_conditions,
                 extensions: [".d.ts"]
               )
               |> file_result(),
             {:ok, declaration} <- declaration_for(path) do
          {:ok, declaration}
        else
          _ -> nil
        end
    end)
  end

  defp file_result({:ok, path}), do: {:ok, path}
  defp file_result(_other), do: :error

  defp declaration_for(path) do
    declaration =
      if String.ends_with?(path, ".d.ts"),
        do: path,
        else: Path.rootname(path) <> ".d.ts"

    if File.regular?(declaration), do: {:ok, declaration}, else: :error
  end

  # A package's `types` field describes its root only.
  defp package_types(specifier, from) do
    with true <- not relative?(specifier) and package_name(specifier) == specifier,
         {:ok, package_dir} <- package_dir(specifier, from),
         {:ok, json} <- File.read(Path.join(package_dir, "package.json")),
         %{} = package <- Jason.decode!(json),
         types when is_binary(types) <- package["types"] || package["typings"] do
      declaration_for(Path.join(package_dir, types))
    else
      _ -> :error
    end
  end

  defp package_dir(name, from) do
    case PackageResolver.find_node_modules(from) do
      nil -> :error
      node_modules -> {:ok, Path.join(node_modules, name)}
    end
  end

  # Each reached package also keeps its `package.json` and license files.
  defp package_files(path, node_modules) do
    package_dir =
      Path.join(node_modules, path |> Path.relative_to(node_modules) |> package_name())

    Path.wildcard(Path.join(package_dir, "{package.json,LICENSE*,license*}"))
  end

  defp sources(dir) do
    dir
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.reject(&String.contains?(Path.relative_to(&1, dir), "node_modules"))
    |> Enum.filter(&(Path.extname(&1) in @source_extensions))
  end

  # Import sources, including type-only imports, re-exports, and `import()` types.
  defp imports(path) do
    with {:ok, source} <- File.read(path),
         {:ok, ast} <- OXC.parse(source, Path.basename(path)) do
      OXC.collect(ast, fn
        %{source: %{value: specifier}} when is_binary(specifier) -> {:keep, specifier}
        _node -> :skip
      end)
    else
      _ -> []
    end
  end

  defp relative?(specifier), do: String.starts_with?(specifier, [".", "/"])

  defp package_name("@" <> _ = specifier),
    do: specifier |> String.split("/") |> Enum.take(2) |> Enum.join("/")

  defp package_name(specifier), do: specifier |> String.split("/", parts: 2) |> hd()

  # `@scope/pkg/sub` is typed by `@types/scope__pkg/sub`, `pkg/sub` by `@types/pkg/sub`.
  defp types_specifier(specifier) do
    name = package_name(specifier)
    subpath = String.replace_prefix(specifier, name, "")
    "@types/" <> String.replace(String.trim_leading(name, "@"), "/", "__") <> subpath
  end
end
