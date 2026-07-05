defmodule Mix.Tasks.Volt.Test do
  @shortdoc "Run Volt JavaScript and TypeScript tests through ExUnit"

  @moduledoc """
  Runs Volt JavaScript and TypeScript tests through generated ExUnit bridge
  modules.

      mix volt.test
      mix volt.test --profile my_app_web

  This first implementation discovers files from `config :volt, :test`, creates
  one ExUnit test per JS/TS test file, and delegates execution/reporting to
  `mix test`.
  """

  use Mix.Task

  alias Volt.Test.Config
  alias Volt.Test.Discovery

  @impl true
  def run(args) do
    Mix.Task.run("app.config")

    {volt_opts, ex_unit_args} = parse_args!(args)
    profile = profile(volt_opts)
    config = Config.read(profile, overrides(volt_opts))
    files = Discovery.files(config)

    if files == [] do
      Mix.shell().info("No Volt JS/TS test files found")
    else
      generated = generate_bridge_files!(files, profile)
      Mix.Task.run("test", generated ++ ex_unit_args)
    end
  end

  defp parse_args!(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args,
        strict: [profile: :string, root: :string, include: :keep, exclude: :keep],
        aliases: [p: :profile]
      )

    if invalid != [] do
      Mix.raise("Invalid volt.test options: #{Enum.map_join(invalid, ", ", &elem(&1, 0))}")
    end

    {opts, argv}
  end

  defp profile(opts) do
    case Keyword.get(opts, :profile) do
      nil -> nil
      profile -> String.to_existing_atom(profile)
    end
  rescue
    ArgumentError -> Mix.raise("Unknown Volt profile #{inspect(Keyword.fetch!(opts, :profile))}")
  end

  defp overrides(opts) do
    opts
    |> Keyword.take([:root])
    |> maybe_put_list(:include, Keyword.get_values(opts, :include))
    |> maybe_put_list(:exclude, Keyword.get_values(opts, :exclude))
  end

  defp maybe_put_list(opts, _key, []), do: opts
  defp maybe_put_list(opts, key, values), do: Keyword.put(opts, key, values)

  defp generate_bridge_files!(files, profile) do
    dir = Path.join([Mix.Project.build_path(), "volt_test", "generated"])
    File.rm_rf!(dir)
    File.mkdir_p!(dir)

    Enum.map(files, fn file ->
      module = module_name(file)
      target = Path.join(dir, Macro.underscore(module) <> ".exs")
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, bridge_source(module, file, profile))
      target
    end)
  end

  defp module_name(file) do
    hash = :erlang.phash2(file) |> Integer.to_string(36)
    "Volt.Generated.JSTest#{hash}"
  end

  defp bridge_source(module, file, profile) do
    profile_ast = Macro.escape(profile)
    file_ast = Macro.escape(file)

    """
    defmodule #{module} do
      use ExUnit.Case, async: false

      @tag :js
      @tag volt_file: #{inspect(file)}
      test #{inspect(file)} do
        assert {:ok, result} = Volt.Test.Runner.run_file(#{inspect(file_ast)}, profile: #{inspect(profile_ast)})
        Volt.Test.Assertions.assert_passed!(result)
      end
    end
    """
  end
end
