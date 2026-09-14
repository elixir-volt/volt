defmodule Volt.Builder.Writer do
  @moduledoc "Writes production JavaScript, CSS, assets, sourcemaps, and manifests."

  def write_js(outdir, filename, code, sourcemap, opts \\ []) do
    artifacts = Volt.Builder.Artifact.javascript(filename, code, sourcemap, opts)

    {:ok, plan} = Volt.Builder.Plan.new(artifacts)
    write_plan(outdir, plan)
  end

  @doc false
  @spec write_plan(String.t(), Volt.Builder.Plan.t()) :: :ok | {:error, term()}
  def write_plan(outdir, %Volt.Builder.Plan{} = plan) do
    Volt.Builder.Publication.write(outdir, plan)
  end

  def write_css(css_parts, outdir, name, hash, bundle_opts) do
    with {:ok, result, plan} <- prepare_css(css_parts, outdir, name, hash, bundle_opts),
         :ok <- write_plan(outdir, plan) do
      {:ok, result}
    end
  end

  def prepare_css([], _outdir, _name, _hash, _bundle_opts),
    do: {:ok, nil, %Volt.Builder.Plan{artifacts: []}}

  def prepare_css(css_parts, outdir, name, hash, bundle_opts) do
    with {:ok, prepared} <- Volt.Builder.CSS.prepare_parts(css_parts, bundle_opts),
         {:ok, css_code} <- Volt.Builder.CSS.compile(prepared.code, bundle_opts),
         css_filename = hashed_name(name, css_code, ".css", hash),
         {:ok, plan} <-
           Volt.Builder.Plan.new([
             %Volt.Builder.Artifact{file: css_filename, content: css_code} | prepared.artifacts
           ]) do
      {:ok,
       %Volt.Builder.OutputFile{
         path: Path.join(outdir, css_filename),
         size: byte_size(css_code),
         assets: prepared.assets
       }, plan}
    end
  end

  def build_style_entry(name, css_code, outdir, hash, source_path \\ nil, bundle_opts \\ []) do
    with {:ok, result, plan} <-
           prepare_style_entry(name, css_code, outdir, hash, source_path, bundle_opts),
         :ok <- write_plan(outdir, plan) do
      {:ok, result}
    end
  end

  @doc "Prepare a standalone stylesheet and its referenced assets without writing files."
  def prepare_style_entry(name, css_code, outdir, hash, source_path, bundle_opts) do
    with {:ok, prepared} <-
           Volt.Builder.CSS.prepare_part({source_path, css_code}, bundle_opts),
         {:ok, css_code} <- Volt.Builder.CSS.compile(prepared.code, bundle_opts),
         css_filename = hashed_name(name, css_code, ".css", hash),
         {:ok, plan} <-
           Volt.Builder.Plan.new([
             %Volt.Builder.Artifact{file: css_filename, content: css_code} | prepared.artifacts
           ]) do
      css_path = Path.join(outdir, css_filename)

      css_result = %Volt.Builder.OutputFile{
        path: css_path,
        size: byte_size(css_code),
        assets: prepared.assets
      }

      manifest =
        %{
          "#{name}.css" =>
            Volt.Builder.ManifestEntry.css(
              "#{name}.css",
              css_filename,
              css_assets(css_filename, css_result)
            )
        }
        |> add_asset_entries(css_result.assets)

      {:ok,
       %Volt.Builder.Result{
         js: [],
         css: css_result,
         styles: [css_result],
         manifest: manifest
       }, plan}
    end
  end

  def write_manifest(outdir, manifest) do
    File.write!(Path.join(outdir, "manifest.json"), Jason.encode!(manifest))
  end

  def build_manifest(name, js_filename, css_result, assets \\ []) do
    manifest = %{
      "#{name}.js" =>
        "#{name}.js"
        |> Volt.Builder.ManifestEntry.js(js_filename, entry: true)
        |> add_js_assets(assets)
    }

    manifest
    |> add_css_to_manifest(name, css_result)
    |> add_asset_entries(assets)
  end

  defp add_js_assets(entry, []), do: entry
  defp add_js_assets(entry, assets), do: %{entry | assets: asset_files(assets)}

  def add_css_to_manifest(manifest, _name, nil), do: manifest

  def add_css_to_manifest(manifest, name, css_result) do
    css_filename = Path.basename(css_result.path)

    manifest
    |> update_in(["#{name}.js"], &%{&1 | css: [css_filename]})
    |> Map.put(
      "#{name}.css",
      Volt.Builder.ManifestEntry.css(
        "#{name}.css",
        css_filename,
        css_assets(css_filename, css_result)
      )
    )
    |> add_asset_entries(css_result.assets)
  end

  def hashed_name(name, content, ext, true) do
    "#{name}-#{Volt.Builder.Naming.hash(content)}#{ext}"
  end

  def hashed_name(name, _content, ext, false), do: "#{name}#{ext}"

  defp css_assets(css_filename, css_result) do
    [css_filename | asset_files(Map.get(css_result, :assets, []))]
  end

  def asset_files(assets) do
    assets
    |> Enum.map(fn
      %Volt.Builder.Asset{file: file} -> file
      file when is_binary(file) -> file
    end)
    |> Enum.uniq()
  end

  def add_asset_entries(manifest, assets) do
    Enum.reduce(assets, manifest, fn
      %Volt.Builder.Asset{src: src, file: file}, acc ->
        Map.put_new(acc, src, Volt.Builder.ManifestEntry.asset(src, file))

      _file, acc ->
        acc
    end)
  end
end
