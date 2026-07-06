defmodule Volt.Test.ConfigTest do
  use ExUnit.Case, async: false

  setup do
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

    :ok
  end

  test "returns defaults" do
    config = Volt.Test.Config.read()

    assert config.root == "assets"
    assert config.include == ["**/*.{test,spec}.{js,ts,jsx,tsx}"]
    assert "node_modules/**" in config.exclude
    assert config.browser == false
    assert config.browsers == [:chromium]
    assert config.timeout == 30_000
  end

  test "reads global test config" do
    Application.put_env(:volt, :test,
      root: "frontend",
      include: ["**/*.spec.ts"],
      browser: true,
      browsers: [:chromium, :firefox],
      timeout: 10_000
    )

    config = Volt.Test.Config.read()

    assert config.root == "frontend"
    assert config.include == ["**/*.spec.ts"]
    assert config.browser == true
    assert config.browsers == [:chromium, :firefox]
    assert config.timeout == 10_000
  end

  test "profile test config overrides global test config" do
    Application.put_env(:volt, :test, root: "assets", include: ["**/*.test.ts"])
    Application.put_env(:volt, :admin_web, test: [root: "admin/assets"])

    config = Volt.Test.Config.read(:admin_web)

    assert config.root == "admin/assets"
    assert config.include == ["**/*.test.ts"]
  end

  test "explicit overrides win over profile and global config" do
    Application.put_env(:volt, :test, root: "assets")
    Application.put_env(:volt, :admin_web, test: [root: "admin/assets"])

    config = Volt.Test.Config.read(:admin_web, root: "override/assets")

    assert config.root == "override/assets"
  end
end
