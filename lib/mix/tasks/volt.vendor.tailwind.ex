defmodule Mix.Tasks.Volt.Vendor.Tailwind do
  use Mix.Task

  @shortdoc "Vendor Tailwind runtime into priv/tailwind.js"

  @moduledoc """
  Vendors the Tailwind compiler runtime for QuickBEAM.

      mix volt.vendor.tailwind

  Reads the installed `tailwindcss` package from `node_modules/` and writes a
  QuickBEAM-compatible runtime wrapper to `priv/tailwind.js`.
  """

  @runtime_rel_path "dist/lib.js"
  @output_path "priv/tailwind.js"

  @impl true
  def run(_args) do
    Mix.Task.run("npm.install")

    source_path = Path.join([File.cwd!(), "node_modules", "tailwindcss", @runtime_rel_path])

    unless File.exists?(source_path) do
      Mix.raise("Tailwind runtime not found at #{source_path}")
    end

    source = File.read!(source_path)
    wrapped = wrap_runtime(source)

    File.mkdir_p!(Path.dirname(@output_path))
    File.write!(@output_path, wrapped)

    Mix.shell().info("Wrote #{@output_path}")
  end

  defp wrap_runtime(source) do
    """
    var TW = (() => {
      var module = { exports: {} };
      var exports = module.exports;
      #{source}
      return {
        compileCss: async function(inputCss, candidates) {
          var css = inputCss == null ? '@import "tailwindcss";' : inputCss;
          var compiler = await module.exports.compile(css, {
            from: 'app.css',
            loadStylesheet: async function(id) {
              if (id === 'tailwindcss') {
                return {
                  base: '.',
                  content: '@import "tailwindcss/theme.css" layer(theme);\\n@import "tailwindcss/preflight.css" layer(base);\\n@import "tailwindcss/utilities.css" layer(utilities);'
                };
              }

              if (id === 'tailwindcss/theme.css') {
                return { base: '.', content: module.exports.Features ? requireAsset('theme') : '' };
              }

              if (id === 'tailwindcss/preflight.css') {
                return { base: '.', content: requireAsset('preflight') };
              }

              if (id === 'tailwindcss/utilities.css') {
                return { base: '.', content: requireAsset('utilities') };
              }

              throw new Error('Unsupported stylesheet: ' + id);
            }
          });

          return compiler.build(candidates || []);
        }
      };

      function requireAsset(kind) {
        if (kind === 'theme') {
          return #{Jason.encode!(File.read!("node_modules/tailwindcss/theme.css"))};
        }

        if (kind === 'preflight') {
          return #{Jason.encode!(File.read!("node_modules/tailwindcss/preflight.css"))};
        }

        if (kind === 'utilities') {
          return #{Jason.encode!(File.read!("node_modules/tailwindcss/utilities.css"))};
        }

        return '';
      }
    })();
    """
  end
end
