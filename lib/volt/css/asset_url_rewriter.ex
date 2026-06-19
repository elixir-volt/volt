defmodule Volt.CSS.AssetURLRewriter do
  @moduledoc """
  Parser-backed CSS asset URL rewriting for production builds.

  Uses Vize/LightningCSS to collect parser-backed URL ranges, then patches the
  original source without round-tripping through the serialized CSS AST.
  """

  @type rewrite_result :: {:ok, String.t()} | {:error, term()}
  @type rewrite_assets_result ::
          {:ok, %{code: String.t(), assets: [String.t() | map()]}} | {:error, term()}

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
    prefix = Keyword.get(opts, :prefix, Volt.Paths.prefix())

    with {:ok, code, {assets, _emitted}} <-
           rewrite_urls(css, [filename: source_path], {[], %{}}, fn url, state ->
             rewrite_build_url(url, state, source_path, outdir, prefix, opts)
           end) do
      {:ok, %{code: code, assets: Enum.reverse(assets)}}
    else
      {:error, reason} -> {:error, {:css_parse_failed, reason}}
    end
  end

  @doc "Rewrite relative CSS asset URLs to dev-server URLs without copying files."
  @spec rewrite_dev(String.t(), String.t() | nil, String.t(), String.t()) :: rewrite_result()
  def rewrite_dev(css, nil, _root, _prefix), do: {:ok, css}

  def rewrite_dev(css, source_path, root, prefix) do
    with {:ok, css} <-
           Vize.CSS.rewrite_urls(css, [filename: source_path], fn url ->
             case dev_url(url, source_path, root, prefix) do
               {:ok, ^url} -> :keep
               {:ok, rewritten} -> {:rewrite, rewritten}
             end
           end) do
      {:ok, css}
    else
      {:error, reason} -> {:error, {:css_parse_failed, reason}}
    end
  end

  defp rewrite_build_url(url, {assets, emitted}, source_path, outdir, prefix, opts) do
    case build_url(url, source_path, outdir, prefix, emitted, opts) do
      {:ok, ^url, emitted, _asset} ->
        {:keep, {assets, emitted}}

      {:ok, rewritten, emitted, asset} ->
        assets = if asset in assets, do: assets, else: [asset | assets]
        {{:rewrite, rewritten}, {assets, emitted}}
    end
  end

  defp build_url(url, source_path, outdir, prefix, emitted, opts) do
    if rewrite_candidate?(url) do
      uri = URI.parse(url)
      asset_path = Path.expand(uri.path || "", Path.dirname(source_path))

      if Volt.Assets.asset?(asset_path) and File.regular?(asset_path) do
        {filename, asset, emitted} = emitted_filename(asset_path, outdir, emitted, opts)
        {:ok, append_suffix(Volt.URL.join(prefix, filename), uri), emitted, asset}
      else
        {:ok, url, emitted, nil}
      end
    else
      {:ok, url, emitted, nil}
    end
  end

  defp dev_url(url, source_path, root, prefix) do
    if rewrite_candidate?(url) do
      uri = URI.parse(url)
      asset_path = Path.expand(uri.path || "", Path.dirname(source_path))

      if Volt.Assets.asset?(asset_path) and File.regular?(asset_path) and
           Volt.Path.inside?(asset_path, root) do
        relative = Path.relative_to(asset_path, root)
        {:ok, append_suffix(Volt.URL.join(prefix, relative), uri)}
      else
        {:ok, url}
      end
    else
      {:ok, url}
    end
  end

  defp emitted_filename(asset_path, outdir, emitted, opts) do
    case Map.fetch(emitted, asset_path) do
      {:ok, {filename, asset}} ->
        {filename, asset, emitted}

      :error ->
        {:ok, filename} = Volt.Assets.copy_hashed(asset_path, outdir)
        asset = Volt.Assets.manifest_asset(asset_path, filename, root: Keyword.get(opts, :root))
        {filename, asset, Map.put(emitted, asset_path, {filename, asset})}
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
