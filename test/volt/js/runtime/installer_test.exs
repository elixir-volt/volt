defmodule Volt.JS.Runtime.InstallerTest do
  use ExUnit.Case, async: false

  alias Volt.JS.Runtime.Installer

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "volt-runtime-installer-test-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    original_cache_dir = Application.get_env(:npm, :cache_dir)
    Application.put_env(:npm, :cache_dir, Path.join(tmp_dir, "npm-cache"))

    on_exit(fn ->
      File.rm_rf!(tmp_dir)

      if original_cache_dir do
        Application.put_env(:npm, :cache_dir, original_cache_dir)
      else
        Application.delete_env(:npm, :cache_dir)
      end
    end)

    %{tmp_dir: tmp_dir}
  end

  test "writes package metadata for an install directory", %{tmp_dir: tmp_dir} do
    install = Installer.install!(%{}, install_dir: tmp_dir)

    metadata = read_metadata(tmp_dir)

    assert install.install_dir == tmp_dir
    assert install.node_modules == Path.join(tmp_dir, "node_modules")
    assert metadata["packages"] == %{}
    assert is_binary(metadata["signature"])
  end

  test "same install directory with different packages rewrites metadata", %{tmp_dir: tmp_dir} do
    Installer.install!(%{}, install_dir: tmp_dir)
    first = read_metadata(tmp_dir)

    Installer.install!(%{"left-pad" => "1.3.0"}, install_dir: tmp_dir)
    second = read_metadata(tmp_dir)

    assert first["signature"] != second["signature"]
    assert second["packages"] == %{"left-pad" => "1.3.0"}
  end

  test "installs a package-owned lockfile without resolving", %{tmp_dir: tmp_dir} do
    package = "volt-locked-only"
    version = "1.0.0"
    cache_package!(package, version)
    source_lock = write_lock!(tmp_dir, %{package => lock_entry(version)})
    install_dir = Path.join(tmp_dir, "install")

    install =
      Installer.install!(%{package => version},
        install_dir: install_dir,
        lockfile: source_lock
      )

    assert File.read!(Path.join(install_dir, "npm.lock")) == File.read!(source_lock)
    assert File.read!(Path.join([install.node_modules, package, "package.json"])) =~ package
  end

  test "includes package-owned lockfile contents in the install signature", %{tmp_dir: tmp_dir} do
    package = "volt-locked-signature"
    version = "1.0.0"
    cache_package!(package, version)
    source_lock = write_lock!(tmp_dir, %{package => lock_entry(version)})
    install_dir = Path.join(tmp_dir, "install")

    Installer.install!(%{package => version}, install_dir: install_dir, lockfile: source_lock)
    first = read_metadata(install_dir)

    source_lock =
      write_lock!(tmp_dir, %{package => %{lock_entry(version) | integrity: "sha512-changed"}})

    Installer.install!(%{package => version}, install_dir: install_dir, lockfile: source_lock)
    second = read_metadata(install_dir)

    assert first["signature"] != second["signature"]
    assert File.read!(Path.join(install_dir, "npm.lock")) == File.read!(source_lock)
  end

  test "rejects a package-owned lockfile with a mismatched direct version", %{tmp_dir: tmp_dir} do
    source_lock = write_lock!(tmp_dir, %{"locked-package" => lock_entry("1.0.0")})

    assert_raise ArgumentError, ~r/version mismatch.*expected 2.0.0, got 1.0.0/, fn ->
      Installer.install!(%{"locked-package" => "2.0.0"},
        install_dir: Path.join(tmp_dir, "install"),
        lockfile: source_lock
      )
    end
  end

  test "rejects an incomplete package-owned dependency graph", %{tmp_dir: tmp_dir} do
    entry = %{lock_entry("1.0.0") | dependencies: %{"missing-transitive" => "^2.0.0"}}
    source_lock = write_lock!(tmp_dir, %{"locked-package" => entry})

    assert_raise ArgumentError, ~r/does not satisfy.*missing-transitive@\^2.0.0/, fn ->
      Installer.install!(%{"locked-package" => "1.0.0"},
        install_dir: Path.join(tmp_dir, "install"),
        lockfile: source_lock
      )
    end
  end

  defp cache_package!(name, version) do
    package_dir = NPM.Cache.package_dir(name, version)
    File.mkdir_p!(package_dir)

    File.write!(
      Path.join(package_dir, "package.json"),
      Jason.encode!(%{name: name, version: version})
    )
  end

  defp write_lock!(tmp_dir, lockfile) do
    path = Path.join(tmp_dir, "source-npm.lock")
    :ok = NPM.Lockfile.write(lockfile, path)
    path
  end

  defp lock_entry(version) do
    %{
      version: version,
      integrity: "sha512-test",
      tarball: "https://registry.npmjs.org/unused.tgz",
      dependencies: %{},
      optional_dependencies: %{},
      has_install_script: false,
      nested_dependencies: %{}
    }
  end

  defp read_metadata(install_dir) do
    install_dir
    |> Path.join("volt-runtime.json")
    |> File.read!()
    |> Jason.decode!()
  end
end
