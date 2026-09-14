defmodule Volt.Build do
  @moduledoc """
  Builds the complete configured frontend output.

  This orchestrator composes Tailwind roots with the ordinary Volt module graph,
  merges their typed build results, and publishes one final manifest.
  """

  @spec run(keyword()) :: {:ok, Volt.Build.Result.t()} | {:error, term()}
  def run(opts \\ []) do
    {profile, opts} = Keyword.pop(opts, :profile)
    config = Volt.Config.build(profile, opts)
    tailwind = Keyword.get(opts, :tailwind, Volt.Config.tailwind(profile))
    entries = List.wrap(config.entry)
    root_outdir = to_string(config.outdir)
    layout = Volt.Build.Layout.new(config.output_layout, config.assets_dir)

    with {:ok, tailwind_result, tailwind_plan} <-
           build_tailwind(tailwind, config, opts, layout),
         {:ok, asset_result, asset_plan} <- build_assets(entries, config, opts, layout) do
      tailwind_result = prefix_manifest(tailwind_result, layout.styles)
      asset_result = prefix_manifest(asset_result, layout.scripts)

      artifacts =
        prefix_artifacts(tailwind_plan, layout.styles) ++
          prefix_artifacts(asset_plan, layout.scripts)

      with {:ok, result} <- build_result(tailwind_result, asset_result),
           {:ok, plan} <-
             Volt.Builder.Plan.new(artifacts ++ manifest_artifacts(result.manifest, opts)),
           :ok <- Volt.Builder.Plan.validate_manifest(plan, result.manifest),
           {:ok, destination, plan} <-
             Volt.PublicDir.prepare_output(
               plan,
               root_outdir,
               Volt.PublicDir.resolve(config.public_dir),
               root_outdir
             ),
           :ok <- Volt.Builder.Writer.write_plan(destination, plan) do
        {:ok, result}
      end
    end
  end

  defp build_tailwind(false, _config, _opts, _layout), do: empty_plan()
  defp build_tailwind(true, config, opts, layout), do: prepare_tailwind([], config, opts, layout)
  defp build_tailwind([], _config, _opts, _layout), do: empty_plan()
  defp build_tailwind(nil, _config, _opts, _layout), do: empty_plan()

  defp build_tailwind(tailwind, config, opts, layout),
    do: prepare_tailwind(tailwind, config, opts, layout)

  defp prepare_tailwind(tailwind, config, opts, layout) do
    overrides =
      []
      |> put_present(:css, opts[:tailwind_css])
      |> put_present(:name, opts[:tailwind_name])
      |> put_present(:sources, opts[:tailwind_sources])

    root = Volt.Config.Tailwind.new(tailwind, overrides)

    Volt.Tailwind.Build.prepare(root,
      outdir: Path.join(to_string(config.outdir), layout.styles),
      hash: config.hash,
      minify: config.minify,
      root: to_string(config.root),
      asset_url_prefix: Volt.URL.join(config.asset_url_prefix, layout.styles)
    )
  end

  defp build_assets([], _config, _opts, _layout), do: empty_plan()

  defp build_assets(entries, config, opts, layout) do
    builder_outdir = Path.join(to_string(config.outdir), layout.scripts)
    asset_url_prefix = Volt.URL.join(config.asset_url_prefix, layout.scripts)

    config
    |> Map.from_struct()
    |> Map.put(:entry, entries)
    |> Map.put(:outdir, builder_outdir)
    |> Map.put(:asset_url_prefix, asset_url_prefix)
    |> Map.put(:write_manifest, false)
    |> Map.merge(Map.new(Keyword.take(opts, [:name])))
    |> Map.to_list()
    |> Volt.Builder.prepare()
  end

  defp empty_plan, do: {:ok, %Volt.Builder.Result{}, %Volt.Builder.Plan{artifacts: []}}

  defp prefix_artifacts(plan, ""), do: plan.artifacts

  defp prefix_artifacts(plan, prefix) do
    Enum.map(plan.artifacts, fn artifact ->
      %{artifact | file: Path.join(prefix, artifact.file)}
    end)
  end

  defp manifest_artifacts(manifest, opts) do
    if Keyword.get(opts, :write_manifest, true),
      do: [%Volt.Builder.Artifact{file: "manifest.json", content: Jason.encode!(manifest)}],
      else: []
  end

  defp build_result(styles_result, assets_result) do
    collisions =
      Volt.Builder.ManifestEntry.conflicts(styles_result.manifest, assets_result.manifest)

    case Enum.sort(collisions) do
      [] ->
        {:ok,
         %Volt.Build.Result{
           assets: assets_result,
           styles: styles_result.styles ++ assets_result.styles,
           manifest: Map.merge(styles_result.manifest, assets_result.manifest)
         }}

      keys ->
        {:error, {:manifest_collision, keys}}
    end
  end

  defp prefix_manifest(result, ""), do: result

  defp prefix_manifest(result, prefix) do
    manifest =
      Map.new(result.manifest, fn {key, %Volt.Builder.ManifestEntry{} = entry} ->
        {key, Volt.Builder.ManifestEntry.prefix_paths(entry, prefix)}
      end)

    %{result | manifest: manifest}
  end

  defp put_present(opts, _key, nil), do: opts
  defp put_present(opts, key, value), do: Keyword.put(opts, key, value)
end
