defmodule Volt.CSS.AssetURLRewriter do
  @moduledoc """
  Parser-backed CSS asset URL rewriting for production builds.

  Uses Vize/LightningCSS to collect parser-backed URL ranges, then patches the
  original source without round-tripping through the serialized CSS AST.
  """

  @type rewrite_result :: {:ok, String.t()} | {:error, term()}
  @type rewrite_assets_result ::
          {:ok, %{code: String.t(), assets: [Volt.Builder.Asset.t()]}} | {:error, term()}

  @doc "Rewrite relative CSS asset URLs to hashed output URLs."
  @spec rewrite(String.t(), String.t() | nil, String.t(), keyword()) :: rewrite_result()
  def rewrite(css, source_path, outdir, opts \\ []) do
    case rewrite_with_assets(css, source_path, outdir, opts) do
      {:ok, %{code: code}} -> {:ok, code}
      {:error, _} = error -> error
    end
  end

  @doc "Rewrite relative CSS asset URLs and return emitted asset filenames."
  @spec rewrite_with_assets(String.t(), String.t() | nil, String.t(), keyword()) ::
          rewrite_assets_result()
  def rewrite_with_assets(css, source_path, outdir, opts \\ [])
  def rewrite_with_assets(css, nil, _outdir, _opts), do: {:ok, %{code: css, assets: []}}

  def rewrite_with_assets(css, source_path, outdir, opts) do
    with {:ok, result} <- prepare(css, source_path, opts) do
      Volt.Assets.write_artifacts(result.artifacts, outdir)

      {:ok, %{code: result.code, assets: result.assets}}
    end
  end

  @doc false
  def prepare(css, source_path, opts \\ [])

  def prepare(css, nil, _opts),
    do: {:ok, %Volt.Builder.CSS.Prepared{code: css, assets: [], artifacts: []}}

  def prepare(css, source_path, opts) do
    prefix = Keyword.get(opts, :prefix, Volt.Paths.prefix())

    with {:ok, code, {assets, emitted}} <-
           rewrite_urls(css, [filename: source_path], {[], %{}}, fn url, state ->
             rewrite_build_url(url, state, source_path, prefix, opts)
           end) do
      artifacts =
        emitted
        |> Enum.map(fn {_path, {_file, _asset, artifact}} -> artifact end)
        |> Enum.sort_by(& &1.file)

      {:ok,
       %Volt.Builder.CSS.Prepared{code: code, assets: Enum.reverse(assets), artifacts: artifacts}}
    else
      {:error, reason} -> {:error, {:css_parse_failed, reason}}
    end
  end

  @doc "Rebase relative asset URLs before an imported stylesheet loses its source location."
  def rebase(css, source_path, output_base) do
    Vize.CSS.rewrite_urls(css, [filename: source_path], fn url ->
      uri = URI.parse(url)

      if rewrite_candidate?(url) and Volt.Assets.asset?(uri.path) do
        absolute = Path.expand(uri.path, Path.dirname(source_path))
        relative = Path.relative_to(absolute, output_base, force: true)
        {:rewrite, append_suffix(relative, uri)}
      else
        :keep
      end
    end)
  end

  @doc "Rewrite relative CSS asset URLs to dev-server URLs without copying files."
  @spec rewrite_dev(String.t(), String.t() | nil, String.t(), String.t()) :: rewrite_result()
  def rewrite_dev(css, source_path, root, prefix, opts \\ [])
  def rewrite_dev(css, nil, _root, _prefix, _opts), do: {:ok, css}

  def rewrite_dev(css, source_path, root, prefix, opts) do
    with {:ok, css} <-
           Vize.CSS.rewrite_urls(css, [filename: source_path], fn url ->
             case dev_url(url, source_path, root, prefix, opts) do
               {:ok, ^url} -> :keep
               {:ok, rewritten} -> {:rewrite, rewritten}
             end
           end) do
      {:ok, css}
    else
      {:error, reason} -> {:error, {:css_parse_failed, reason}}
    end
  end

  defp rewrite_build_url(url, {assets, emitted}, source_path, prefix, opts) do
    case build_url(url, source_path, prefix, emitted, opts) do
      {:ok, ^url, emitted, _asset} ->
        {:keep, {assets, emitted}}

      {:ok, rewritten, emitted, asset} ->
        assets = if asset in assets, do: assets, else: [asset | assets]
        {{:rewrite, rewritten}, {assets, emitted}}
    end
  end

  defp build_url(url, source_path, prefix, emitted, opts) do
    if rewrite_candidate?(url) do
      uri = URI.parse(url)
      asset_path = Path.expand(uri.path || "", Path.dirname(source_path))

      if Volt.Assets.asset?(asset_path) and File.regular?(asset_path) do
        {filename, asset, emitted} = emitted_filename(asset_path, emitted, opts)
        {:ok, append_suffix(Volt.URL.join(prefix, filename), uri), emitted, asset}
      else
        {:ok, url, emitted, nil}
      end
    else
      {:ok, url, emitted, nil}
    end
  end

  defp dev_url(url, source_path, root, prefix, opts) do
    if rewrite_candidate?(url) do
      uri = URI.parse(url)
      asset_path = Path.expand(uri.path || "", Path.dirname(source_path))

      if Volt.Assets.asset?(asset_path) and File.regular?(asset_path) do
        cond do
          Volt.Path.inside?(asset_path, root) ->
            relative = Path.relative_to(asset_path, root)
            {:ok, append_suffix(Volt.URL.join(prefix, relative), uri)}

          grant = Keyword.get(opts, :grant_asset) ->
            {:ok, append_suffix(grant.(asset_path), uri)}

          true ->
            {:ok, url}
        end
      else
        {:ok, url}
      end
    else
      {:ok, url}
    end
  end

  defp emitted_filename(asset_path, emitted, opts) do
    case Map.fetch(emitted, asset_path) do
      {:ok, {filename, asset, _artifact}} ->
        {filename, asset, emitted}

      :error ->
        artifact = Volt.Assets.prepare_hashed(asset_path)
        filename = artifact.file
        asset = Volt.Assets.manifest_asset(asset_path, filename, root: Keyword.get(opts, :root))
        {filename, asset, Map.put(emitted, asset_path, {filename, asset, artifact})}
    end
  end

  defp rewrite_candidate?(url) do
    uri = URI.parse(url)

    is_binary(uri.path) and uri.path != "" and is_nil(uri.scheme) and is_nil(uri.host) and
      not String.starts_with?(url, ["/", "#", "//"])
  end

  defp append_suffix(path, %{query: query, fragment: fragment}) do
    path
    |> Volt.URL.append_query(query)
    |> Volt.URL.append_fragment(fragment)
  end

  defp rewrite_urls(css, opts, state, fun) do
    {:ok, agent} = Agent.start_link(fn -> state end)

    try do
      case Vize.CSS.rewrite_urls(css, opts, fn url ->
             Agent.get_and_update(agent, fn state ->
               {action, state} = fun.(url, state)
               {action, state}
             end)
           end) do
        {:ok, css} -> {:ok, css, Agent.get(agent, & &1)}
        {:error, reason} -> {:error, reason}
      end
    after
      Agent.stop(agent)
    end
  end
end
