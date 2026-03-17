defmodule Volt.EnvTest do
  use ExUnit.Case, async: true

  @fixture_dir Path.expand("fixtures/env", __DIR__)

  setup do
    File.mkdir_p!(@fixture_dir)
    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "parse_env_file/1" do
    test "parses key=value pairs" do
      path = Path.join(@fixture_dir, ".env")
      File.write!(path, "VOLT_API_URL=https://api.test\nVOLT_DEBUG=true\n")

      result = Volt.Env.parse_env_file(path)
      assert result["VOLT_API_URL"] == "https://api.test"
      assert result["VOLT_DEBUG"] == "true"
    end

    test "ignores comments and blank lines" do
      path = Path.join(@fixture_dir, ".env")
      File.write!(path, "# comment\n\nVOLT_KEY=value\n")

      result = Volt.Env.parse_env_file(path)
      assert result == %{"VOLT_KEY" => "value"}
    end

    test "handles quoted values" do
      path = Path.join(@fixture_dir, ".env")
      File.write!(path, ~s(VOLT_MSG="hello world"\nVOLT_NAME='test'\n))

      result = Volt.Env.parse_env_file(path)
      assert result["VOLT_MSG"] == "hello world"
      assert result["VOLT_NAME"] == "test"
    end

    test "handles export prefix" do
      path = Path.join(@fixture_dir, ".env")
      File.write!(path, "export VOLT_KEY=exported\n")

      result = Volt.Env.parse_env_file(path)
      assert result["VOLT_KEY"] == "exported"
    end

    test "preserves inner quotes" do
      path = Path.join(@fixture_dir, ".env")
      File.write!(path, ~s(VOLT_VAL="it's \\"fine\\""\n))

      result = Volt.Env.parse_env_file(path)
      assert result["VOLT_VAL"] =~ "fine"
    end

    test "mismatched quotes are preserved" do
      path = Path.join(@fixture_dir, ".env")
      File.write!(path, ~s(VOLT_VAL="no closing single\n))

      result = Volt.Env.parse_env_file(path)
      assert result["VOLT_VAL"] == ~s("no closing single)
    end
  end

  describe "define/1" do
    test "generates define map with VOLT_ prefix" do
      File.write!(Path.join(@fixture_dir, ".env"), "VOLT_API=http://localhost\nSECRET=hidden\n")

      defines = Volt.Env.define(root: @fixture_dir, mode: "development")

      assert defines["import.meta.env.VOLT_API"] == ~s("http://localhost")
      refute Map.has_key?(defines, "import.meta.env.SECRET")
    end

    test "includes MODE, DEV, PROD" do
      defines = Volt.Env.define(root: @fixture_dir, mode: "development")

      assert defines["import.meta.env.MODE"] == ~s("development")
      assert defines["import.meta.env.DEV"] == "true"
      assert defines["import.meta.env.PROD"] == "false"
    end

    test "production mode" do
      defines = Volt.Env.define(root: @fixture_dir, mode: "production")

      assert defines["import.meta.env.DEV"] == "false"
      assert defines["import.meta.env.PROD"] == "true"
    end

    test "mode-specific env files override base" do
      File.write!(Path.join(@fixture_dir, ".env"), "VOLT_URL=base\n")
      File.write!(Path.join(@fixture_dir, ".env.production"), "VOLT_URL=prod\n")

      defines = Volt.Env.define(root: @fixture_dir, mode: "production")
      assert defines["import.meta.env.VOLT_URL"] == ~s("prod")
    end

    test "extra env takes precedence" do
      File.write!(Path.join(@fixture_dir, ".env"), "VOLT_KEY=file\n")

      defines = Volt.Env.define(root: @fixture_dir, env: %{"VOLT_KEY" => "override"})
      assert defines["import.meta.env.VOLT_KEY"] == ~s("override")
    end
  end
end
