defmodule Volt.Tailwind.Build do
  @moduledoc "Builds a configured Tailwind root into a Volt asset result."

  @spec build(Volt.Config.Tailwind.t(), keyword()) ::
          {:ok, Volt.Builder.Result.t()} | {:error, term()}
  def build(%Volt.Config.Tailwind{} = root, opts) do
    with {:ok, result, plan} <- prepare(root, opts),
         :ok <- Volt.Builder.Writer.write_plan(Keyword.fetch!(opts, :outdir), plan) do
      {:ok, result}
    end
  end

  @doc "Compile a Tailwind root and prepare output without writing assets."
  @spec prepare(Volt.Config.Tailwind.t(), keyword()) ::
          {:ok, Volt.Builder.Result.t(), Volt.Builder.Plan.t()} | {:error, term()}
  def prepare(%Volt.Config.Tailwind{} = root, opts) do
    with {:ok, css_input} <- read_css(root.css),
         {:ok, css} <-
           Volt.Tailwind.Runtime.compile_once(
             css_input,
             [],
             css_base(root.css),
             %{
               base: Path.expand(Keyword.get(opts, :root, File.cwd!())),
               sources: scan_sources(root.sources)
             }
           ) do
      Volt.Builder.Writer.prepare_style_entry(
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

  defp scan_sources(sources) do
    sources
    |> Enum.map(fn source ->
      %{
        base: Path.expand(source.base),
        pattern: source.pattern,
        negated: Map.get(source, :negated, false)
      }
    end)
  end

  defp read_css(nil), do: {:ok, nil}
  defp read_css(path), do: File.read(path)

  defp css_base(nil), do: File.cwd!()
  defp css_base(path), do: Path.dirname(path)
end
