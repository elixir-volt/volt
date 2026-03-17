defmodule Volt.EnvTest do
  use ExUnit.Case, async: true

  @fixture_dir Path.expand("fixtures/env", __DIR__)

  setup do
    File.mkdir_p!(@fixture_dir)
    on_exit(fn -> File.rm_rf!(@fixture_dir) end)
    :ok
  end

  describe "load_env_files/2" do
    test "parses key=value pairs" do
      File.write!(Path.join(@fixture_dir, ".env"), "VOLT_API=https://api.test\nVOLT_DEBUG=true\n")

      result = Volt.Env.load_env_files(@fixture_dir, "production")
      assert result["VOLT_API"] == "https://api.test"
      assert result["VOLT_DEBUG"] == "true"
    end

    test "ignores comments and blank lines" do
      File.write!(Path.join(@fixture_dir, ".env"), "# comment\n\nVOLT_KEY=value\n")

      result = Volt.Env.load_env_files(@fixture_dir, "production")
      assert result["VOLT_KEY"] == "value"
    end

    test "handles quoted values" do
      File.write!(Path.join(@fixture_dir, ".env"), ~s(VOLT_MSG="hello world"\nVOLT_NAME='test'\n))

      result = Volt.Env.load_env_files(@fixture_dir, "production")
      assert result["VOLT_MSG"] == "hello world"
      assert result["VOLT_NAME"] == "test"
    end

    test "handles export prefix" do
      File.write!(Path.join(@fixture_dir, ".env"), "export VOLT_KEY=exported\n")

      result = Volt.Env.load_env_files(@fixture_dir, "production")
      assert result["VOLT_KEY"] == "exported"
    end

    test "mode-specific env files override base" do
      File.write!(Path.join(@fixture_dir, ".env"), "VOLT_URL=base\n")
      File.write!(Path.join(@fixture_dir, ".env.production"), "VOLT_URL=prod\n")

      result = Volt.Env.load_env_files(@fixture_dir, "production")
      assert result["VOLT_URL"] == "prod"
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

    test "extra env takes precedence" do
      File.write!(Path.join(@fixture_dir, ".env"), "VOLT_KEY=file\n")

      defines = Volt.Env.define(root: @fixture_dir, env: %{"VOLT_KEY" => "override"})
      assert defines["import.meta.env.VOLT_KEY"] == ~s("override")
    end
  end
end
