defmodule Volt.Builder.Writer do
  @moduledoc false

  def write_js(outdir, filename, code, sourcemap) do
    File.write!(Path.join(outdir, filename), code)

    if sourcemap do
      File.write!(Path.join(outdir, "#{filename}.map"), sourcemap)
    end
  end

  def write_css([], _outdir, _name, _hash, _bundle_opts), do: nil

  def write_css(css_parts, outdir, name, hash, bundle_opts) do
    css_code = Enum.join(css_parts, "\n")

    css_code =
      case Vize.compile_css(css_code, minify: bundle_opts[:minify] || false) do
        {:ok, %{code: minified}} -> minified
        _ -> css_code
      end

    css_filename = hashed_name(name, css_code, ".css", hash)
    css_path = Path.join(outdir, css_filename)
    File.write!(css_path, css_code)
    %{path: css_path, size: byte_size(css_code)}
  end

  def build_style_entry(name, css_code, outdir, hash) do
    File.mkdir_p!(outdir)

    css_filename = hashed_name(name, css_code, ".css", hash)
    css_path = Path.join(outdir, css_filename)
    File.write!(css_path, css_code)

    manifest = %{
      "#{name}.css" => %{
        "file" => css_filename,
        "src" => "#{name}.css",
        "assets" => [css_filename]
      }
    }

    write_manifest(outdir, manifest)

    {:ok,
     %{
       js: [],
       css: %{path: css_path, size: byte_size(css_code)},
       manifest: manifest
     }}
  end

  def write_manifest(outdir, manifest) do
    File.write!(Path.join(outdir, "manifest.json"), :json.encode(manifest))
  end

  def build_manifest(name, js_filename, css_result) do
    manifest = %{
      "#{name}.js" => %{
        "file" => js_filename,
        "src" => "#{name}.js"
      }
    }

    if css_result do
      css_filename = Path.basename(css_result.path)

      manifest
      |> put_in(["#{name}.js", "css"], [css_filename])
      |> Map.put("#{name}.css", %{
        "file" => css_filename,
        "src" => "#{name}.css",
        "assets" => [css_filename]
      })
    else
      manifest
    end
  end

  def hashed_name(name, content, ext, true) do
    "#{name}-#{Volt.Format.content_hash(content)}#{ext}"
  end

  def hashed_name(name, _content, ext, false), do: "#{name}#{ext}"
end
