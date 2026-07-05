defmodule Volt.Test.DiscoveryTest do
  use ExUnit.Case, async: false

  alias Volt.Test.Config

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "volt-test-discovery-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{tmp_dir: tmp_dir}
  end

  test "discovers sorted JS and TS test files from include globs", %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "src/b.test.ts", "")
    write!(tmp_dir, "src/a.spec.js", "")
    write!(tmp_dir, "src/not-a-test.ts", "")

    config = %Config{root: tmp_dir, include: ["**/*.{test,spec}.{js,ts}"]}

    assert Volt.Test.Discovery.files(config) == [
             Path.join([tmp_dir, "src", "a.spec.js"]),
             Path.join([tmp_dir, "src", "b.test.ts"])
           ]
  end

  test "excludes ignored files", %{tmp_dir: tmp_dir} do
    write!(tmp_dir, "src/app.test.ts", "")
    write!(tmp_dir, "src/generated/ignored.test.ts", "")
    write!(tmp_dir, "node_modules/pkg/pkg.test.ts", "")

    config = %Config{
      root: tmp_dir,
      include: ["**/*.test.ts"],
      exclude: ["src/generated/**", "node_modules/**"]
    }

    assert Volt.Test.Discovery.files(config) == [Path.join([tmp_dir, "src", "app.test.ts"])]
  end

  test "reads config when called with profile and overrides", %{tmp_dir: tmp_dir} do
    original_env = Application.get_all_env(:volt)

    :volt
    |> Application.get_all_env()
    |> Enum.each(fn {key, _value} -> Application.delete_env(:volt, key) end)

    on_exit(fn ->
      :volt
      |> Application.get_all_env()
      |> Enum.each(fn {key, _value} -> Application.delete_env(:volt, key) end)

      Enum.each(original_env, fn {key, value} -> Application.put_env(:volt, key, value) end)
    end)

    write!(tmp_dir, "app/app.test.ts", "")

    Application.put_env(:volt, :my_app_web,
      test: [root: Path.join(tmp_dir, "app"), include: ["**/*.test.ts"]]
    )

    assert Volt.Test.Discovery.files(:my_app_web, []) == [
             Path.join([tmp_dir, "app", "app.test.ts"])
           ]
  end

  defp write!(root, path, contents) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end
end
