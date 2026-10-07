defmodule Volt.Builder.Declarations do
  @moduledoc """
  Writes the type declarations of a library entry as one `.d.ts`.

  Each TypeScript module of the entry's graph is emitted through OXC's isolated
  declarations, which need explicit types on exported declarations and report
  the ones they cannot infer; a plugin-owned module, such as a `.vue` file, is
  declared by its plugin. The declarations are then bundled the way
  `rollup-plugin-dts` bundles them: the graph is walked from the entry along
  the declarations' own imports, so modules that only hold types are included;
  only the declarations the entry's exports reach are kept, along with ambient
  declarations such as `declare module`; imports of other packages are hoisted
  and merged; and two modules declaring the same name are told apart by
  renaming the one further from the entry.

  Declarations are module-scoped, so names resolve at the top level of each
  module: an identifier is the module's own declaration of that name, or what
  the module imports under that name. Property names, type parameters and
  parameters are left alone.
  """

  alias Volt.Builder.Resolver

  @declarations [
    :ts_type_alias_declaration,
    :ts_interface_declaration,
    :class_declaration,
    :function_declaration,
    :ts_declare_function,
    :ts_enum_declaration,
    :ts_module_declaration
  ]

  @doc """
  Bundle the declarations of the module at `entry` into one `.d.ts` source.

  Returns `{:error, {:declarations, path, reason}}` when a module's declarations
  cannot be emitted (`reason` is then the emitter's diagnostics) or hold a
  construct the bundler does not handle (`reason` is then a message).
  """
  @spec bundle(Path.t(), Volt.Builder.Context.t()) :: {:ok, String.t()} | {:error, term()}
  def bundle(entry, ctx) do
    entry = Path.expand(entry)

    with {:ok, modules} <- collect(entry, ctx, %{}) do
      bundle_modules(entry, modules)
    end
  end

  # ── Collecting ────────────────────────────────────────────────────

  # `modules` maps a path to its declarations: the imports of other packages
  # as written, the bindings imported from project modules, the statements,
  # and the exports.
  defp collect(path, _ctx, modules) when is_map_key(modules, path), do: {:ok, modules}

  defp collect(path, ctx, modules) do
    with {:ok, dts} <- declaration_source(path, ctx),
         {:ok, ast} <- OXC.parse(dts, Path.basename(path) <> ".d.ts"),
         {:ok, module} <- read_module(path, dts, ast, ctx) do
      Enum.reduce_while(module.sources, {:ok, Map.put(modules, path, module)}, fn dep,
                                                                                  {:ok, acc} ->
        case collect(dep, ctx, acc) do
          {:ok, acc} -> {:cont, {:ok, acc}}
          error -> {:halt, error}
        end
      end)
    else
      {:error, {:declarations, _path, _reason}} = error -> error
      {:error, reason} -> {:error, {:declarations, path, reason}}
    end
  end

  defp declaration_source(path, ctx) do
    with {:ok, source} <- File.read(path) do
      case Volt.PluginRunner.declaration(ctx.plugins, path, source, []) do
        {:ok, dts} -> {:ok, dts}
        {:error, reason} -> {:error, reason}
        nil -> OXC.isolated_declarations(source, Path.basename(path))
      end
    end
  end

  defp read_module(path, dts, ast, ctx) do
    module = %{
      path: path,
      external_imports: [],
      imports: %{},
      statements: [],
      exports: %{},
      export_all: [],
      sources: []
    }

    ast.body
    |> Enum.reduce_while({:ok, module, 0}, fn node, {:ok, module, previous_end} ->
      case read_statement(node, {dts, previous_end}, ctx, module) do
        {:ok, module} -> {:cont, {:ok, module, node.end}}
        {:error, message} -> {:halt, {:error, {:declarations, path, message}}}
      end
    end)
    |> case do
      {:ok, module, _end} ->
        {:ok,
         %{
           module
           | statements: Enum.reverse(module.statements),
             external_imports: Enum.reverse(module.external_imports),
             sources: module.sources |> Enum.reverse() |> Enum.uniq()
         }}

      error ->
        error
    end
  end

  defp read_statement(%{type: :import_declaration} = node, {dts, _previous_end}, ctx, module) do
    case resolve_source(node.source.value, module.path, ctx) do
      {:project, dep} ->
        imports =
          Enum.reduce(node.specifiers, module.imports, fn specifier, imports ->
            Map.put(imports, specifier.local.name, {dep, imported_name(specifier)})
          end)

        {:ok, %{module | imports: imports, sources: [dep | module.sources]}}

      :external ->
        {:ok, %{module | external_imports: [slice(dts, node) | module.external_imports]}}
    end
  end

  defp read_statement(%{type: :export_all_declaration} = node, _dts, ctx, module) do
    case {node.exported, resolve_source(node.source.value, module.path, ctx)} do
      {nil, {:project, dep}} ->
        {:ok, %{module | export_all: [dep | module.export_all], sources: [dep | module.sources]}}

      {nil, :external} ->
        {:error,
         "`export * from #{inspect(node.source.value)}` of another package is not bundled"}

      {%{name: name}, _} ->
        {:error, "`export * as #{name}` is not bundled; import the module and export it"}
    end
  end

  # `export { a, b as c }`, with or without `from`.
  defp read_statement(
         %{type: :export_named_declaration, declaration: nil} = node,
         _dts,
         ctx,
         module
       ) do
    with {:ok, from} <- export_source(node, module.path, ctx) do
      exports =
        Enum.reduce(node.specifiers, module.exports, fn specifier, exports ->
          target =
            if from,
              do: {:import, from, specifier.local.name},
              else: {:binding, specifier.local.name}

          Map.put(exports, specifier.exported.name, target)
        end)

      {:ok, %{module | exports: exports, sources: List.wrap(from) ++ module.sources}}
    end
  end

  defp read_statement(
         %{type: :export_named_declaration, declaration: declaration} = node,
         dts,
         _ctx,
         module
       ) do
    statement = statement(module.path, dts, declaration, node)
    exports = Enum.reduce(statement.names, module.exports, &Map.put(&2, &1, {:binding, &1}))
    {:ok, %{module | statements: [statement | module.statements], exports: exports}}
  end

  defp read_statement(
         %{type: :export_default_declaration, declaration: %{type: :identifier, name: name}},
         _dts,
         _ctx,
         module
       ) do
    {:ok, %{module | exports: Map.put(module.exports, "default", {:binding, name})}}
  end

  defp read_statement(
         %{type: :export_default_declaration, declaration: declaration} = node,
         dts,
         _ctx,
         module
       ) do
    case statement(module.path, dts, declaration, node) do
      %{names: [name]} = statement ->
        exports = Map.put(module.exports, "default", {:binding, name})
        {:ok, %{module | statements: [statement | module.statements], exports: exports}}

      _anonymous ->
        {:error, "an anonymous `export default` cannot be referenced from the bundle; name it"}
    end
  end

  defp read_statement(node, dts, _ctx, module) do
    {:ok, %{module | statements: [statement(module.path, dts, node, node) | module.statements]}}
  end

  defp export_source(%{source: nil}, _path, _ctx), do: {:ok, nil}

  defp export_source(%{source: %{value: specifier}}, path, ctx) do
    case resolve_source(specifier, path, ctx) do
      {:project, dep} ->
        {:ok, dep}

      :external ->
        {:error, "`export { ... } from #{inspect(specifier)}` of another package is not bundled"}
    end
  end

  defp imported_name(%{type: :import_default_specifier}), do: "default"
  defp imported_name(%{type: :import_namespace_specifier}), do: "*"
  defp imported_name(%{imported: imported}), do: imported.name

  # A module of the project is bundled; anything that resolves into a package,
  # or is external to the build, stays an import for the consumer to resolve.
  defp resolve_source(specifier, importer, ctx) do
    case Resolver.resolve(specifier, importer, ctx) do
      {:ok, resolved} ->
        {resolved_path, _query} = Volt.URL.split_query(resolved)

        if Resolver.inside_node_modules?(resolved) or not File.regular?(resolved_path),
          do: :external,
          else: {:project, Path.expand(resolved_path)}

      _skip_or_error ->
        :external
    end
  end

  # A top-level statement: its text, the names it declares and the
  # identifiers it refers to, with offsets into the text.
  #
  # The text is the declaration without its `export`, led by the comments
  # between the previous statement and this one, which hold its JSDoc. A
  # declaration that `export default` left without `declare` gets it back, as
  # it no longer has the `export` that implied it.
  defp statement(path, {dts, previous_end}, node, outer) do
    lead = dts |> binary_part(previous_end, outer.start - previous_end) |> String.trim()
    declare = if implied_declare?(node), do: "declare ", else: ""
    prefix = if lead == "", do: declare, else: lead <> "\n" <> declare

    %{
      module: path,
      text: prefix <> slice(dts, node),
      names: declared_names(node),
      references: references(node, node.start - byte_size(prefix))
    }
  end

  defp implied_declare?(%{type: type, declare: false})
       when type in [
              :class_declaration,
              :function_declaration,
              :ts_declare_function,
              :variable_declaration,
              :ts_enum_declaration
            ],
       do: true

  defp implied_declare?(_node), do: false

  defp slice(source, %{start: start, end: finish}), do: binary_part(source, start, finish - start)

  # ── Names ─────────────────────────────────────────────────────────

  defp declared_names(%{type: :variable_declaration, declarations: declarations}),
    do: for(%{id: %{type: :identifier, name: name}} <- declarations, do: name)

  defp declared_names(%{type: type, id: %{type: :identifier, name: name}})
       when type in @declarations,
       do: [name]

  defp declared_names(_node), do: []

  # Names the statement binds itself, property names, type parameters,
  # parameters and member accesses are not references.
  defp references(node, base) do
    {_node, {references, bound}} =
      OXC.postwalk(node, {[], MapSet.new()}, fn
        %{type: :identifier, name: name, start: start, end: finish} = id, {refs, bound} ->
          {id, {[%{start: start - base, end: finish - base, name: name} | refs], bound}}

        other, {refs, bound} ->
          {other, {refs, bind(other, bound)}}
      end)

    references
    |> Enum.reject(&MapSet.member?(bound, &1.start + base))
    |> Enum.sort_by(& &1.start)
  end

  defp bind(%{type: :ts_type_parameter, name: %{start: start}}, bound),
    do: MapSet.put(bound, start)

  defp bind(%{type: :ts_qualified_name, right: %{start: start}}, bound),
    do: MapSet.put(bound, start)

  defp bind(%{type: :ts_enum_member, id: %{start: start}}, bound), do: MapSet.put(bound, start)

  defp bind(%{type: :variable_declarator, id: %{start: start}}, bound),
    do: MapSet.put(bound, start)

  defp bind(%{type: :member_expression, computed: false, property: %{start: start}}, bound),
    do: MapSet.put(bound, start)

  defp bind(%{computed: false, key: %{type: :identifier, start: start}}, bound),
    do: MapSet.put(bound, start)

  defp bind(%{type: type, id: %{type: :identifier, start: start}} = node, bound)
       when type in @declarations,
       do: node |> Map.delete(:id) |> bind(MapSet.put(bound, start))

  # Parameters bind their names: `(items: string[])` refers to nothing.
  defp bind(%{params: params}, bound) when is_list(params) do
    Enum.reduce(params, bound, fn
      %{type: :identifier, start: start}, bound -> MapSet.put(bound, start)
      %{type: :assignment_pattern, left: %{start: start}}, bound -> MapSet.put(bound, start)
      %{type: :rest_element, argument: %{start: start}}, bound -> MapSet.put(bound, start)
      _pattern, bound -> bound
    end)
  end

  defp bind(_node, bound), do: bound

  # ── Bundling ──────────────────────────────────────────────────────

  defp bundle_modules(entry, modules) do
    declared = declared_index(modules)

    with {:ok, entry_exports} <- exports_of(entry, modules, MapSet.new()),
         roots = for({_exported, target} <- entry_exports, do: target),
         {:ok, reached} <- reach(roots, modules, declared, MapSet.new()) do
      statements = emitted_statements(modules, reached, entry)
      renames = renames(statements, entry)
      paths = statements |> Enum.map(& &1.module) |> Enum.uniq()

      parts = [
        external_imports(paths, modules),
        Enum.map_join(statements, "\n", &rewrite(&1, modules, renames)),
        export_list(entry_exports, renames)
      ]

      {:ok, Enum.map_join(Enum.reject(parts, &(&1 == "")), "\n", & &1) <> "\n"}
    end
  end

  # What a module exports, as `%{exported_name => {module, declared_name}}`,
  # following re-exports and `export *` to the declaring module.
  defp exports_of(path, modules, visiting) do
    if MapSet.member?(visiting, path) do
      {:ok, %{}}
    else
      module = Map.fetch!(modules, path)
      visiting = MapSet.put(visiting, path)

      with {:ok, starred} <- star_exports(module.export_all, modules, visiting) do
        named_exports(module, modules, visiting, starred)
      end
    end
  end

  defp named_exports(module, modules, visiting, acc) do
    Enum.reduce_while(module.exports, {:ok, acc}, fn {exported, target}, {:ok, acc} ->
      case resolve_target(target, module, modules, visiting) do
        {:ok, resolved} -> {:cont, {:ok, Map.put(acc, exported, resolved)}}
        error -> {:halt, error}
      end
    end)
  end

  defp star_exports(sources, modules, visiting) do
    Enum.reduce_while(sources, {:ok, %{}}, fn dep, {:ok, acc} ->
      case exports_of(dep, modules, visiting) do
        {:ok, exports} -> {:cont, {:ok, Map.merge(acc, Map.delete(exports, "default"))}}
        error -> {:halt, error}
      end
    end)
  end

  defp resolve_target({:import, dep, name}, module, modules, visiting),
    do: resolve_imported(module.path, dep, name, modules, visiting)

  defp resolve_target({:binding, name}, module, modules, visiting) do
    case resolve_name(module, name, modules, visiting) do
      {:ok, target} ->
        {:ok, target}

      :none ->
        {:error,
         {:declarations, module.path, "`#{name}` is exported but not declared or imported"}}

      error ->
        error
    end
  end

  # A name at a module's top level is its own declaration or an import.
  defp resolve_name(module, name, modules, visiting \\ MapSet.new()) do
    cond do
      Enum.any?(module.statements, &(name in &1.names)) ->
        {:ok, {module.path, name}}

      match?(%{^name => _}, module.imports) ->
        {dep, imported} = module.imports[name]
        resolve_imported(module.path, dep, imported, modules, visiting)

      true ->
        :none
    end
  end

  defp resolve_imported(importer, _dep, "*", _modules, _visiting) do
    {:error,
     {:declarations, importer,
      "`import * as` of a project module is not bundled; import its names"}}
  end

  defp resolve_imported(importer, dep, name, modules, visiting) do
    with {:ok, exports} <- exports_of(dep, modules, visiting) do
      case exports do
        %{^name => resolved} ->
          {:ok, resolved}

        _ ->
          {:error,
           {:declarations, importer, "#{Path.relative_to_cwd(dep)} does not export `#{name}`"}}
      end
    end
  end

  # `%{{module, name} => [{statement_index, statement}]}`: an interface merged
  # over several statements, or an overloaded function, is declared by all of
  # them.
  defp declared_index(modules) do
    for {path, module} <- modules,
        {statement, index} <- Enum.with_index(module.statements),
        name <- statement.names,
        reduce: %{} do
      acc -> Map.update(acc, {path, name}, [{index, statement}], &[{index, statement} | &1])
    end
  end

  # The statements reachable from `roots` through references, as a set of
  # `{module, statement_index}`.
  defp reach([], _modules, _declared, reached), do: {:ok, reached}

  defp reach([{path, name} | rest], modules, declared, reached) do
    pending =
      declared
      |> Map.get({path, name}, [])
      |> Enum.reject(fn {index, _statement} -> MapSet.member?(reached, {path, index}) end)

    reached =
      Enum.reduce(pending, reached, fn {index, _statement}, acc ->
        MapSet.put(acc, {path, index})
      end)

    pending
    |> Enum.reduce_while({:ok, rest}, fn {_index, statement}, {:ok, rest} ->
      case reference_targets(statement, modules) do
        {:ok, targets} -> {:cont, {:ok, Enum.reduce(targets, rest, &[&1 | &2])}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, rest} -> reach(rest, modules, declared, reached)
      error -> error
    end
  end

  # Where a statement's references lead. Names that are neither declared nor
  # imported, such as globals and the lib's types, lead nowhere.
  defp reference_targets(statement, modules) do
    module = modules[statement.module]

    statement.references
    |> Enum.map(& &1.name)
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn name, {:ok, acc} ->
      case resolve_name(module, name, modules) do
        {:ok, target} -> {:cont, {:ok, [target | acc]}}
        :none -> {:cont, {:ok, acc}}
        error -> {:halt, error}
      end
    end)
  end

  # Reached statements and ambient ones, dependencies before dependents with
  # the entry last, and a module's statements in their own order.
  defp emitted_statements(modules, reached, entry) do
    entry
    |> module_order(modules, {[], MapSet.new()})
    |> elem(0)
    |> Enum.reverse()
    |> Enum.flat_map(fn path ->
      modules[path].statements
      |> Enum.with_index()
      |> Enum.filter(fn {statement, index} ->
        statement.names == [] or MapSet.member?(reached, {path, index})
      end)
      |> Enum.map(fn {statement, _index} -> statement end)
    end)
  end

  defp module_order(path, modules, {order, seen}) do
    if MapSet.member?(seen, path) do
      {order, seen}
    else
      {order, seen} =
        Enum.reduce(
          modules[path].sources,
          {order, MapSet.put(seen, path)},
          &module_order(&1, modules, &2)
        )

      {[path | order], seen}
    end
  end

  # Names declared by more than one module keep their spelling in the module
  # nearest the entry, in emission order, and gain a `$1`, `$2`, ... elsewhere.
  defp renames(statements, entry) do
    statements
    |> Enum.sort_by(&(&1.module != entry))
    |> Enum.flat_map(&Enum.map(&1.names, fn name -> {&1.module, name} end))
    |> Enum.uniq()
    |> Enum.reduce({%{}, MapSet.new()}, fn {module, name}, {renames, taken} ->
      if MapSet.member?(taken, name) do
        renamed =
          Enum.find(
            Stream.map(Stream.iterate(1, &(&1 + 1)), &"#{name}$#{&1}"),
            &(not MapSet.member?(taken, &1))
          )

        {Map.put(renames, {module, name}, renamed), MapSet.put(taken, renamed)}
      else
        {renames, MapSet.put(taken, name)}
      end
    end)
    |> elem(0)
  end

  defp emitted_name({module, name}, renames), do: Map.get(renames, {module, name}, name)

  # A statement's text with every identifier that resolves to a declaration
  # spelled as that declaration is emitted, and its own names likewise.
  defp rewrite(statement, modules, renames) do
    module = modules[statement.module]

    reference_patches =
      Enum.flat_map(statement.references, fn reference ->
        with {:ok, target} <- resolve_name(module, reference.name, modules),
             emitted when emitted != reference.name <- emitted_name(target, renames) do
          [Volt.JS.Patch.new(reference.start, reference.end, emitted)]
        else
          _unresolved_or_unchanged -> []
        end
      end)

    own_patches =
      Enum.flat_map(statement.names, fn name ->
        case Map.fetch(renames, {statement.module, name}) do
          {:ok, renamed} -> declaration_name_patches(statement.text, name, renamed)
          :error -> []
        end
      end)

    OXC.patch_string(statement.text, reference_patches ++ own_patches)
  end

  # The binding identifier of a renamed declaration, found by parsing the
  # statement again: it was excluded from the references on purpose.
  defp declaration_name_patches(text, name, renamed) do
    {:ok, ast} = OXC.parse(text, "statement.d.ts")

    for node <- ast.body,
        %{start: start, end: finish} <- declaration_ids(node),
        binary_part(text, start, finish - start) == name,
        do: Volt.JS.Patch.new(start, finish, renamed)
  end

  defp declaration_ids(%{type: :variable_declaration, declarations: declarations}),
    do: Enum.map(declarations, & &1.id)

  defp declaration_ids(%{id: %{type: :identifier} = id}), do: [id]
  defp declaration_ids(_node), do: []

  # Imports of other packages, as written, in the order the modules are
  # emitted, without repeats.
  defp external_imports(paths, modules) do
    paths
    |> Enum.flat_map(&modules[&1].external_imports)
    |> Enum.uniq()
    |> Enum.join("\n")
  end

  defp export_list(entry_exports, renames) do
    specifiers =
      entry_exports
      |> Enum.sort()
      |> Enum.map(fn {exported, target} ->
        emitted = emitted_name(target, renames)
        if emitted == exported, do: emitted, else: "#{emitted} as #{exported}"
      end)

    if specifiers == [], do: "", else: "export { #{Enum.join(specifiers, ", ")} };"
  end
end
