defmodule Volt.Assets do
  @moduledoc """
  Static asset handling — images, fonts, SVGs, and other non-code files.

  Small assets (below the inline threshold) are inlined as base64 data URIs.
  Larger assets are copied with content-hashed filenames.

  ## Import patterns

      // Inlined as data URI when small enough
      import icon from './icon.svg'
      // icon = "data:image/svg+xml;base64,..."

      // Forced public URL
      import photo from './photo.jpg?url'
      // photo = "/assets/photo-a1b2c3d4.jpg"

      // Raw file contents
      import text from './message.txt?raw'

  JavaScript `new URL("./asset.ext", import.meta.url)` references and CSS
  `url("./asset.ext")` references are also routed through this asset pipeline in
  production builds.
  """

  @default_inline_limit 4096

  @doc "Check if a path is a known asset type."
  @spec asset?(String.t()) :: boolean()
  def asset?(path) when is_binary(path) do
    path
    |> Volt.URL.split_query()
    |> elem(0)
    |> Volt.MIME.asset?()
  end

  @doc """
  Resolve an asset-like specifier to an existing source file path.

  This is the filesystem side of Volt's Vite-like asset semantics. It resolves
  aliases, relative specifiers, root-relative specifiers, and plain asset-root
  paths without pulling in build graph concerns such as externals or package
  imports.

  ## Options

    * `:root` — asset root for `/logo.svg` and `"logo.svg"` specifiers
    * `:importer` — source file used as the base for relative specifiers
    * `:aliases` — Volt alias map, typically from `Volt.Config.build().aliases`
    * `:extensions` — extensions to try when the specifier has none

  """
  @spec resolve(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def resolve(specifier, opts \\ []) when is_binary(specifier) do
    {specifier, _query} = Volt.URL.split_query(specifier)

    specifier
    |> candidates(opts)
    |> Enum.find_value({:error, {:not_found, specifier}}, &resolve_candidate(&1, opts))
  end

  @doc "Resolve an asset-like specifier or raise `ArgumentError`."
  @spec resolve!(String.t(), keyword()) :: String.t()
  def resolve!(specifier, opts \\ []) do
    case resolve(specifier, opts) do
      {:ok, path} ->
        path

      {:error, reason} ->
        raise ArgumentError, "could not resolve asset #{inspect(specifier)}: #{inspect(reason)}"
    end
  end

  @doc """
  Generate a JS module that exports asset content or a URL.

  ## Options

    * `:raw` — export the file contents as a string
    * `:url` — force a public URL instead of inlining
    * `:inline` — force a data URI
    * `:no_inline` — force a public URL even for small assets
    * `:inline_limit` — byte threshold for default inlining (default: 4096)
    * `:prefix` — URL prefix for referenced assets (default: `"/assets"`)
    * `:outdir` — output directory for copied assets (production only)
    * `:url_path` — dev-server URL to export when no `:outdir` is provided
  """
  @spec to_js_module(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def to_js_module(path, opts \\ []) do
    case emit_js_module(path, opts) do
      {:ok, %{code: code}} -> {:ok, code}
      {:error, _} = error -> error
    end
  end

  @doc "Generate a JS module for an asset and return emitted asset metadata."
  @spec emit_js_module(String.t(), keyword()) ::
          {:ok, %{code: String.t(), assets: [String.t() | map()]}} | {:error, term()}
  def emit_js_module(path, opts \\ []) do
    cond do
      Keyword.get(opts, :raw, false) ->
        raw_asset(path)

      Keyword.get(opts, :url, false) ->
        reference_asset(path, opts)

      Keyword.get(opts, :inline, false) ->
        inline_asset(path)

      Keyword.get(opts, :no_inline, false) ->
        reference_asset(path, opts)

      true ->
        limit = Keyword.get(opts, :inline_limit, @default_inline_limit)

        case File.stat(path) do
          {:ok, %{size: size}} when size <= limit ->
            inline_asset(path)

          {:ok, _stat} ->
            reference_asset(path, opts)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Copy an asset to the output directory with a content-hashed filename.

  Returns `{:ok, hashed_filename}`.
  """
  @spec copy_hashed(String.t(), String.t()) :: {:ok, String.t()}
  def copy_hashed(source_path, outdir) do
    content = File.read!(source_path)
    ext = Path.extname(source_path)
    name = Path.basename(source_path, ext)
    hash = Volt.Format.content_hash(content)
    filename = "#{name}-#{hash}#{ext}"
    dest = Path.join(outdir, filename)

    File.mkdir_p!(outdir)
    File.write!(dest, content)

    {:ok, filename}
  end

  @doc "Build manifest metadata for an emitted asset."
  @spec manifest_asset(String.t(), String.t(), keyword()) :: map()
  def manifest_asset(source_path, filename, opts \\ []) do
    %{
      src: source_path |> asset_src(Keyword.get(opts, :root)) |> String.trim_leading("/"),
      file: filename
    }
  end

  @doc "Get MIME type for a file extension."
  @spec mime_type(String.t()) :: String.t()
  def mime_type(path), do: Volt.MIME.type(path)

  defp candidates(specifier, opts) do
    aliases = Keyword.get(opts, :aliases, %{})

    case Volt.JS.Resolver.resolve(specifier, aliases) do
      {:ok, path} ->
        [{:alias, path}]

      :pass ->
        standard_candidates(specifier, opts)
    end
  end

  defp standard_candidates("/" <> relative = specifier, opts) do
    specifier
    |> maybe_absolute_candidate()
    |> maybe_add_root_candidate(relative, opts)
  end

  defp standard_candidates("." <> _ = specifier, opts) do
    case Keyword.get(opts, :importer) do
      nil -> []
      importer -> [{:relative, Path.expand(specifier, Path.dirname(importer))}]
    end
  end

  defp standard_candidates(specifier, opts) do
    case Keyword.get(opts, :root) do
      nil -> [{:cwd, Path.expand(specifier)} | maybe_absolute_candidate(specifier)]
      root -> [{:root, Path.expand(specifier, root)} | maybe_absolute_candidate(specifier)]
    end
  end

  defp maybe_add_root_candidate(candidates, relative, opts) do
    case Keyword.get(opts, :root) do
      nil -> candidates
      root -> [{:root, Path.expand(relative, root)} | candidates]
    end
  end

  defp maybe_absolute_candidate(specifier) do
    if Path.type(specifier) == :absolute, do: [{:absolute, Path.expand(specifier)}], else: []
  end

  defp resolve_candidate({_kind, path}, opts) do
    path
    |> try_file(Keyword.get(opts, :extensions, []))
    |> case do
      {:ok, resolved} -> {:ok, resolved}
      :error -> nil
    end
  end

  defp try_file(path, extensions) do
    cond do
      File.regular?(path) ->
        {:ok, path}

      Path.extname(path) == "" ->
        extensions
        |> Enum.map(&normalize_extension/1)
        |> Enum.find_value(:error, fn extension ->
          candidate = path <> extension
          if File.regular?(candidate), do: {:ok, candidate}
        end)

      true ->
        :error
    end
  end

  defp normalize_extension("." <> _ = extension), do: extension
  defp normalize_extension(extension), do: "." <> extension

  defp raw_asset(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, asset_module(content)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp inline_asset(path) do
    content = File.read!(path)
    mime = mime_type(path)
    encoded = Base.encode64(content)
    {:ok, asset_module("data:#{mime};base64,#{encoded}")}
  end

  defp reference_asset(path, opts) do
    prefix = Keyword.get(opts, :prefix, Volt.Paths.prefix())

    case Keyword.get(opts, :outdir) do
      nil ->
        url = Keyword.get(opts, :url_path) || Volt.URL.join(prefix, Path.basename(path))
        {:ok, asset_module(url)}

      outdir ->
        {:ok, filename} = copy_hashed(path, outdir)
        asset = manifest_asset(path, filename, root: Keyword.get(opts, :root))
        {:ok, asset_module(Volt.URL.join(prefix, filename), [asset])}
    end
  end

  defp asset_src(source_path, nil), do: Path.basename(source_path)

  defp asset_src(source_path, root) do
    expanded_source = Path.expand(source_path)
    expanded_root = Path.expand(root)

    if Volt.Path.inside?(expanded_source, expanded_root) do
      Path.relative_to(expanded_source, expanded_root)
    else
      Path.basename(source_path)
    end
  end

  defp asset_module(value, assets \\ []) do
    %{code: export_default_literal(value), assets: assets}
  end

  defp export_default_literal(value) do
    OXC.parse!("export default $value;", "asset-module.js")
    |> OXC.bind(value: {:literal, value})
    |> OXC.codegen!()
  end
end
