defmodule Volt.JS.Runtime.PackageSetTest do
  use ExUnit.Case, async: false

  alias Volt.JS.Runtime.PackageSet

  @runtime_modules [Volt.Plugin.Svelte, Volt.Plugin.Solid, Volt.Tailwind.Loader]

  test "built-in package sets ship exact direct versions in valid npm_ex locks" do
    Enum.each(@runtime_modules, fn module ->
      set = module.runtime_package_set()
      lockfile_path = PackageSet.lockfile_path(set)

      assert File.regular?(lockfile_path)
      assert NPM.Lockfile.version(lockfile_path) == 1
      assert {:ok, lockfile} = NPM.Lockfile.read(lockfile_path)
      assert {:ok, policy} = NPM.Lockfile.read_policy(lockfile_path)
      assert NPM.Lockfile.policy_matches?(policy)

      Enum.each(set.packages, fn {package, exact_version} ->
        assert %{version: ^exact_version} = Map.fetch!(lockfile, package)
      end)
    end)
  end

  test "runtime opts cannot replace a package set's packages or lockfile" do
    set = PackageSet.bundled(:volt, :fixture, %{"fixture" => "1.0.0"})

    opts =
      PackageSet.runtime_opts(set,
        packages: %{"other" => "2.0.0"},
        lockfile: "/tmp/other.lock",
        bundle: true
      )

    assert opts[:packages] == %{"fixture" => "1.0.0"}
    assert opts[:lockfile] == PackageSet.lockfile_path(set)
    assert opts[:bundle]
  end

  test "built-in package sets use configured resolution when the bundled lock policy is incompatible" do
    registry = "https://npm.example.test"
    env = ~w(NPM_REGISTRY NPM_MIRROR NPM_EX_ALLOWED_REGISTRIES)
    previous = Map.new(env, &{&1, System.get_env(&1)})

    Enum.each(env, &System.put_env(&1, registry))

    on_exit(fn ->
      Enum.each(previous, fn
        {name, nil} -> System.delete_env(name)
        {name, value} -> System.put_env(name, value)
      end)
    end)

    set = Volt.Plugin.Svelte.runtime_package_set()
    opts = PackageSet.runtime_opts(set)

    assert opts[:packages] == %{"svelte" => "5.56.8"}
    refute Keyword.has_key?(opts, :lockfile)
  end

  @tag :integration
  @tag :tmp_dir
  test "built-in package sets install their packaged locks without re-resolving", %{
    tmp_dir: tmp_dir
  } do
    Enum.each(@runtime_modules, fn module ->
      set = module.runtime_package_set()
      source_lock = PackageSet.lockfile_path(set)

      install =
        PackageSet.install!(set,
          install_dir: Path.join(tmp_dir, Atom.to_string(set.name)),
          force: true
        )

      installed_lock = Path.join(install.install_dir, "npm.lock")

      assert File.read!(installed_lock) == File.read!(source_lock)
    end)
  end
end
