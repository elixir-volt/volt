defmodule Volt.Tailwind.Build do
  @moduledoc "Builds a configured Tailwind root into a Volt asset result."

  @spec build(Volt.Config.Tailwind.t(), keyword()) ::
          {:ok, Volt.Builder.Result.t()} | {:error, term()}
  def build(%Volt.Config.Tailwind{} = root, opts) do
    with {:ok, css_input} <- read_css(root.css),
         {:ok, css} <-
           Volt.Tailwind.build(
             key: Keyword.fetch!(opts, :key),
             sources: root.sources,
             css: css_input,
             css_base: css_base(root.css),
             minify: false
           ) do
      Volt.Builder.Writer.build_style_entry(
        root.name,
        css,
        Keyword.fetch!(opts, :outdir),
        Keyword.get(opts, :hash, true),
        root.css,
        minify: Keyword.get(opts, :minify, true),
        root: Keyword.get(opts, :root, File.cwd!()),
        asset_url_prefix: Keyword.get(opts, :asset_url_prefix, Volt.Paths.prefix())
      )
    end
  end

  defp read_css(nil), do: {:ok, nil}
  defp read_css(path), do: File.read(path)

  defp css_base(nil), do: File.cwd!()
  defp css_base(path), do: Path.dirname(path)
end
