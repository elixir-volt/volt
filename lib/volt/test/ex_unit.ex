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
      tests = collect_tests!(file, profile)

      [{_compiled_module, _bytecode}] =
        Code.compile_quoted(bridge_module(module, file, profile, tests), file)
    end

    module
  end

  defp collect_tests!(file, profile) do
    case Volt.Test.Runner.collect_file(file, profile: profile) do
      {:ok, [_ | _] = tests} -> tests
      {:ok, []} -> raise "Volt JS test file #{file} did not define any tests"
      {:error, reason} -> raise "could not collect Volt JS tests from #{file}: #{inspect(reason)}"
    end
  end

  defp module_name(file) do
    hash = :erlang.phash2(Path.expand(file)) |> Integer.to_string(36)
    Module.concat([Volt.Generated.JSTest, "Test#{hash}"])
  end

  defp bridge_module(module, file, profile, tests) do
    test_defs = Enum.map(tests, &test_definition(file, profile, &1))

    quote do
      defmodule unquote(module) do
        use ExUnit.Case, async: false

        unquote_splicing(test_defs)
      end
    end
  end

  defp test_definition(file, profile, %{"id" => test_id} = test) do
    name = test["fullName"] || test["name"] || inspect(test_id)
    function = Macro.unique_var(:name, __MODULE__)

    tags = test_tags(file, test)

    register =
      quote do
        unquote(function) =
          ExUnit.Case.register_test(
            __MODULE__,
            unquote(file),
            unquote(test_line(test)),
            :test,
            unquote(name),
            unquote(Macro.escape(tags))
          )
      end

    body =
      quote do
        assert {:ok, result} =
                 Volt.Test.Runner.run_test(unquote(file), unquote(test_id),
                   profile: unquote(profile)
                 )

        Volt.Test.Assertions.assert_passed!(result)
      end

    def_ast = {:def, [], [{{:unquote, [], [function]}, [], [{:_, [], Elixir}]}, [do: body]]}
    {:__block__, [], [register, def_ast]}
  end

  defp test_tags(file, test) do
    [
      js: true,
      volt_file: file,
      volt_test_id: test["id"],
      volt_tags: test["tags"] || []
    ] ++ skip_tags(test)
  end

  defp skip_tags(%{"mode" => "skip"} = test), do: [skip: test["skipReason"] || true]
  defp skip_tags(%{"mode" => "todo"} = test), do: [skip: test["skipReason"] || "TODO"]
  defp skip_tags(_test), do: []

  defp test_line(%{"line" => line}) when is_integer(line) and line > 0, do: line
  defp test_line(_test), do: 1
end
