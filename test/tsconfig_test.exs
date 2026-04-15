defmodule Volt.JS.TSConfigTest do
  use ExUnit.Case, async: true

  @fixture_dir Path.expand("fixtures/tsconfig", __DIR__)

  setup do
    File.mkdir_p!(@fixture_dir)

    on_exit(fn ->
      File.rm_rf!(@fixture_dir)
    end)

    :ok
  end

  describe "read_paths/1" do
    test "reads paths from tsconfig.json" do
      write_tsconfig!(%{
        "compilerOptions" => %{
          "paths" => %{
            "@/*" => ["./src/*"],
            "@components/*" => ["./src/components/*"]
          }
        }
      })

      paths = Volt.JS.TSConfig.read_paths(tsconfig_path())
      assert paths["@"] =~ "src"
      assert paths["@components"] =~ "src/components"
    end

    test "respects baseUrl" do
      write_tsconfig!(%{
        "compilerOptions" => %{
          "baseUrl" => "./frontend",
          "paths" => %{
            "@/*" => ["./lib/*"]
          }
        }
      })

      paths = Volt.JS.TSConfig.read_paths(tsconfig_path())
      assert paths["@"] =~ "frontend/lib"
    end

    test "returns empty map when no paths" do
      write_tsconfig!(%{
        "compilerOptions" => %{
          "target" => "ES2022"
        }
      })

      assert %{} = Volt.JS.TSConfig.read_paths(tsconfig_path())
    end

    test "returns empty map when file doesn't exist" do
      assert %{} = Volt.JS.TSConfig.read_paths(Path.join(@fixture_dir, "missing.json"))
    end

    test "handles exact paths without globs" do
      write_tsconfig!(%{
        "compilerOptions" => %{
          "paths" => %{
            "~utils" => ["./src/utils"]
          }
        }
      })

      paths = Volt.JS.TSConfig.read_paths(tsconfig_path())
      assert paths["~utils"] =~ "src/utils"
    end
  end

  defp tsconfig_path, do: Path.join(@fixture_dir, "tsconfig.json")

  defp write_tsconfig!(content) do
    File.write!(tsconfig_path(), :json.encode(content))
  end
end
