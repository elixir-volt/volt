defmodule Volt.Formatter do
  @moduledoc """
  A `mix format` plugin that formats JavaScript and TypeScript files with oxfmt.

  ## Setup

  Add `Volt.Formatter` to your `.formatter.exs`:

      [
        plugins: [Volt.Formatter],
        inputs: [
          "{mix,.formatter}.exs",
          "{config,lib,test}/**/*.{ex,exs}",
          "assets/**/*.{js,ts,jsx,tsx}"
        ]
      ]

  ## Configuration

  Set oxfmt options under the `:volt` key of the same file:

      [
        plugins: [Volt.Formatter],
        volt: [semi: false, single_quote: true, print_width: 100]
      ]

  Without that key, options come from `.oxfmtrc.json` / `.prettierrc.json`.
  See the "Formatting and Linting" guide for details.
  """

  @behaviour Mix.Tasks.Format

  @impl true
  def features(_opts) do
    [extensions: Volt.JS.Extensions.formattable()]
  end

  @impl true
  def format(contents, opts) do
    filename = opts[:file] || extension_to_filename(opts[:extension]) || "input.ts"
    format_opts = Volt.JS.Format.load_config(opts)

    OXC.Format.run!(contents, filename, format_opts)
  end

  defp extension_to_filename(nil), do: nil
  defp extension_to_filename(ext), do: "input#{ext}"
end
