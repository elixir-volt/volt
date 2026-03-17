defmodule Volt do
  @moduledoc """
  Elixir-native frontend build tool.

  Provides a dev server with hot module replacement (HMR) and production
  builds for JavaScript, TypeScript, Vue SFCs, and CSS — powered by
  OXC and Vize Rust NIFs. No Node.js required at runtime.

  ## Setup

  Add Volt to your Phoenix endpoint as a Plug:

      plug Volt.DevServer,
        root: "assets/src",
        target: :es2020

  Or use the Mix tasks:

      mix volt.build       # Production build
  """
end
