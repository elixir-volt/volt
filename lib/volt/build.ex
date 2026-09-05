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

    with {:ok, tailwind_result} <- build_tailwind(tailwind, config, opts, profile),
         {:ok, asset_result} <- build_assets(entries, config, opts) do
      tailwind_result = prefix_manifest(tailwind_result, "css")
      asset_result = prefix_manifest(asset_result, "js")
      result = build_result(tailwind_result, asset_result)
      :ok = write_manifest(root_outdir, result.manifest)
      {:ok, result}
    end
  end

  defp build_tailwind([], _config, _opts, _profile), do: {:ok, %Volt.Builder.Result{}}
  defp build_tailwind(nil, _config, _opts, _profile), do: {:ok, %Volt.Builder.Result{}}

  defp build_tailwind(tailwind, config, opts, profile) do
    overrides =
      []
      |> put_present(:css, opts[:tailwind_css])
      |> put_present(:name, opts[:tailwind_name])
      |> put_present(:sources, opts[:tailwind_sources])

    root = Volt.Config.Tailwind.new(tailwind, overrides)

    css_key = root.css || {:default_css, root.name}

    Volt.Tailwind.Build.build(root,
      key: {:build, profile || :default, css_key},
      outdir: Path.join(to_string(config.outdir), "css"),
      hash: config.hash,
      minify: config.minify,
      root: to_string(config.root),
      asset_url_prefix: Volt.URL.join(config.asset_url_prefix, "css")
    )
  end

  defp build_assets([], _config, _opts), do: {:ok, %Volt.Builder.Result{}}

  defp build_assets(entries, config, opts) do
    builder_outdir = Path.join(to_string(config.outdir), "js")
    asset_url_prefix = Volt.URL.join(config.asset_url_prefix, "js")

    config
    |> Map.from_struct()
    |> Map.put(:entry, entries)
    |> Map.put(:outdir, builder_outdir)
    |> Map.put(:asset_url_prefix, asset_url_prefix)
    |> Map.put(:write_manifest, false)
    |> Map.merge(Map.new(Keyword.take(opts, [:name])))
    |> Map.to_list()
    |> Volt.Builder.build()
  end

  defp write_manifest(root_outdir, manifest) do
    File.mkdir_p!(root_outdir)
    Volt.Builder.Writer.write_manifest(root_outdir, manifest)
  end

  defp build_result(styles_result, assets_result) do
    %Volt.Build.Result{
      assets: assets_result,
      styles: List.wrap(styles_result.css) ++ List.wrap(assets_result.css),
      manifest: Map.merge(styles_result.manifest, assets_result.manifest)
    }
  end

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
