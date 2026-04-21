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

  Reads options from `config :volt, :format` or falls back to
  `.oxfmtrc.json` / `.prettierrc.json`. See `Volt.JS.Format` for details.
  """

  @behaviour Mix.Tasks.Format

  @extensions ~w(.js .ts .jsx .tsx .mjs .mts)

  @impl true
  def features(_opts) do
    [extensions: @extensions]
  end

  @impl true
  def format(contents, opts) do
    filename = opts[:file] || extension_to_filename(opts[:extension]) || "input.ts"
    format_opts = Volt.JS.Format.load_config()

    OXC.Format.run!(contents, filename, format_opts)
  end

  defp extension_to_filename(nil), do: nil
  defp extension_to_filename(ext), do: "input#{ext}"
end
