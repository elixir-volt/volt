defmodule Volt.JS.Runtime.Installer do
  @moduledoc false

  @spec install!(map(), keyword()) :: %{install_dir: String.t(), node_modules: String.t()}
  def install!(packages, opts \\ []) when is_map(packages) do
    Application.ensure_all_started(:req)

    id = install_id(packages)
    install_dir = Keyword.get(opts, :install_dir, default_install_dir(id))
    node_modules = Path.join(install_dir, "node_modules")
    lockfile_path = Path.join(install_dir, "npm.lock")

    with_lock(id, fn ->
      if Keyword.get(opts, :force, false) do
        File.rm_rf!(install_dir)
      end

      unless install_intact?(lockfile_path, node_modules) do
        File.mkdir_p!(install_dir)
        resolve_and_link!(packages, node_modules, lockfile_path)
      end
    end)

    %{install_dir: install_dir, node_modules: node_modules}
  end

  defp resolve_and_link!(packages, node_modules, lockfile_path) do
    NPM.Resolver.clear_cache()

    case NPM.Resolver.resolve(packages) do
      {:ok, resolved} ->
        {_nested, flat} = Map.pop(resolved, :nested, %{})
        lockfile = build_lockfile(flat)
        NPM.Lockfile.write(lockfile, lockfile_path)
        NPM.Linker.link(lockfile, node_modules)

      {:error, message} ->
        raise "NPM package resolution failed:\n#{message}"
    end
  end

  defp build_lockfile(resolved) do
    for {name, version} <- resolved, into: %{} do
      {:ok, packument} = NPM.Registry.get_packument(name)
      info = Map.fetch!(packument.versions, version)

      {name,
       %{
         version: version,
         integrity: info.dist.integrity,
         tarball: info.dist.tarball,
         dependencies: info.dependencies,
         optional_dependencies: info.optional_dependencies
       }}
    end
  end

  defp install_intact?(lockfile_path, node_modules) do
    case NPM.Lockfile.read(lockfile_path) do
      {:ok, lockfile} when lockfile != %{} ->
        Enum.all?(lockfile, fn {name, _} ->
          File.exists?(Path.join([node_modules, name, "package.json"]))
        end)

      _ ->
        false
    end
  end

  defp with_lock(id, fun) do
    :global.trans({__MODULE__, id}, fun, [node()], :infinity)
  end

  defp install_id(packages) do
    packages
    |> Enum.sort()
    |> :erlang.term_to_binary()
    |> :erlang.md5()
    |> Base.encode16(case: :lower)
  end

  defp default_install_dir(id) do
    root =
      System.get_env("VOLT_JS_RUNTIME_DIR") ||
        Path.join(NPM.Cache.dir(), "volt-js-runtimes")

    Path.join(root, id)
  end
end
