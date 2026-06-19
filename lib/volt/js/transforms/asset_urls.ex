defmodule Volt.JS.Transforms.AssetURLs do
  @moduledoc """
  Rewrites `new URL("./asset.ext", import.meta.url)` references to asset imports.

  Vite treats relative asset URL constructors as part of the module graph so
  production builds can copy, hash, and rewrite the referenced file. Volt does
  the same by converting the asset argument into a generated `?url` import before
  the normal import rewriting and bundling phases run.

  Only relative specifiers that point at known static asset extensions are
  rewritten. Absolute URLs, package URLs, and non-asset files are left unchanged.
  """

  alias Volt.JS.Patch

  @doc """
  Rewrites matching asset URL constructors in `source`.

  Returns the original source unchanged when parsing fails or no matching
  constructor is found.
  """
  @spec rewrite(String.t(), String.t()) :: String.t()
  def rewrite(source, filename) do
    case OXC.select(source, filename, :asset_urls) do
      {:ok, refs} ->
        rewrites = Enum.filter(refs, &relative_asset_specifier?(&1.specifier))
        if rewrites == [], do: source, else: apply_rewrites(source, rewrites)

      {:error, _} ->
        source
    end
  end

  defp relative_asset_specifier?(specifier) do
    {path, _query} = Volt.URL.split_query(specifier)

    (String.starts_with?(path, "./") or String.starts_with?(path, "../")) and
      Volt.Assets.asset?(path)
  end

  defp apply_rewrites(source, rewrites) do
    {imports, patches} =
      rewrites
      |> Enum.with_index()
      |> Enum.map_reduce([], fn {ref, index}, patches ->
        specifier = Patch.selector_specifier(ref)
        ident = "__volt_asset_url_#{index}"

        import_line = [
          "import ",
          ident,
          " from ",
          Jason.encode!(Volt.URL.append_query(specifier, "url")),
          ";"
        ]

        {import_line, [Patch.replace_selector(ref, ident) | patches]}
      end)

    [Enum.intersperse(imports, "\n"), "\n", Patch.apply(source, patches)]
    |> IO.iodata_to_binary()
  end
end
