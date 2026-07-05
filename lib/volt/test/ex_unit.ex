defmodule Volt.Test.ExUnit do
  @moduledoc """
  Registers Volt JavaScript and TypeScript test files as ordinary ExUnit tests.

  Add it to `test/test_helper.exs` after `ExUnit.start/1`:

      ExUnit.start(exclude: [:integration])
      Volt.Test.ExUnit.install()

  Configuration is read from `config :volt, :test` and supports the same
  profile-style overrides as the rest of Volt:

      config :volt, :test,
        root: "assets",
        include: ["**/*.{test,spec}.{js,ts,jsx,tsx}"]

  This keeps `mix test` as the single test entry point. JavaScript and
  TypeScript files are represented as generated ExUnit modules and participate
  in normal ExUnit tags, formatters, failures, and CI behavior.
  """

  alias Volt.Test.Config
  alias Volt.Test.Discovery

  @spec install(keyword()) :: [module()]
  def install(opts \\ []) do
    profile = Keyword.get(opts, :profile)
    config = Config.read(profile, Keyword.delete(opts, :profile))

    config
    |> Discovery.files()
    |> Enum.map(&define_test_module(&1, profile))
  end

  defp define_test_module(file, profile) do
    module = module_name(file)

    unless Code.ensure_loaded?(module) do
      [{_compiled_module, _bytecode}] =
        Code.compile_string(bridge_source(module, file, profile), file)
    end

    module
  end

  defp module_name(file) do
    hash = :erlang.phash2(Path.expand(file)) |> Integer.to_string(36)
    Module.concat([Volt.Generated.JSTest, "Test#{hash}"])
  end

  defp bridge_source(module, file, profile) do
    """
    defmodule #{inspect(module)} do
      use ExUnit.Case, async: false

      @tag :js
      @tag volt_file: #{inspect(file)}
      test #{inspect(file)} do
        assert {:ok, result} = Volt.Test.Runner.run_file(#{inspect(file)}, profile: #{inspect(profile)})
        Volt.Test.Assertions.assert_passed!(result)
      end
    end
    """
  end
end
