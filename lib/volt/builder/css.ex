defmodule Volt.Builder.CSS do
  @moduledoc false

  def prepare_parts(css_parts, bundle_opts) do
    css_parts
    |> Enum.reduce_while({:ok, []}, fn part, {:ok, acc} ->
      case prepare_part(part, bundle_opts) do
        {:ok, prepared} -> {:cont, {:ok, [prepared | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} ->
        parts = Enum.reverse(reversed)

        {:ok,
         %Volt.Builder.CSS.Prepared{
           code: Enum.map_join(parts, "\n", & &1.code),
           assets: parts |> Enum.flat_map(& &1.assets) |> Enum.uniq(),
           artifacts: Enum.flat_map(parts, & &1.artifacts)
         }}

      {:error, _} = error ->
        error
    end
  end

  def prepare_part({source_path, css}, bundle_opts) do
    with {:ok, css} <- Volt.CSS.Imports.inline(css, source_path, bundle_opts) do
      Volt.CSS.AssetURLRewriter.prepare(css, source_path,
        prefix: Keyword.get(bundle_opts, :asset_url_prefix, Volt.Paths.prefix()),
        root: Keyword.get(bundle_opts, :root)
      )
    end
  end

  def prepare_part(css, _bundle_opts),
    do: {:ok, %Volt.Builder.CSS.Prepared{code: css, assets: [], artifacts: []}}

  def bundle_parts(css_parts, fun) when is_function(fun, 1) do
    css_parts
    |> Enum.reduce_while({:ok, [], []}, fn css_part, {:ok, code_parts, assets} ->
      case fun.(css_part) do
        {:ok, %{code: code, assets: part_assets}} ->
          {:cont, {:ok, [code | code_parts], merge_assets(assets, part_assets)}}

        {:error, _} = error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, code_parts, assets} ->
        {:ok, %{code: code_parts |> Enum.reverse() |> Enum.join("\n"), assets: assets}}

      {:error, _} = error ->
        error
    end
  end

  def rewrite_parts(css_parts, outdir, bundle_opts) do
    bundle_parts(css_parts, &rewrite_part(&1, outdir, bundle_opts))
  end

  def rewrite_part({source_path, css}, outdir, bundle_opts) do
    with {:ok, css} <- Volt.CSS.Imports.inline(css, source_path, bundle_opts) do
      Volt.CSS.AssetURLRewriter.rewrite_with_assets(css, source_path, outdir,
        prefix: Keyword.get(bundle_opts, :asset_url_prefix, Volt.Paths.prefix()),
        root: Keyword.get(bundle_opts, :root)
      )
    end
  end

  def rewrite_part(css, _outdir, _bundle_opts), do: {:ok, %{code: css, assets: []}}

  def compile(css_code, bundle_opts) do
    case Vize.CSS.compile(css_code, minify: bundle_opts[:minify] || false) do
      {:ok, %{errors: [_ | _] = errors}} -> {:error, {:css_compile_failed, errors}}
      {:ok, %{code: code}} -> {:ok, code}
    end
  end

  def merge_assets(left, right) do
    Enum.reduce(right, left, fn asset, acc ->
      if asset in acc, do: acc, else: [asset | acc]
    end)
  end
end
