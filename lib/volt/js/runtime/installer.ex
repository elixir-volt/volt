defmodule Volt.JS.Runtime.Installer do
  @moduledoc "Installs isolated npm runtime packages for QuickBEAM-backed plugins."

  require Logger

  alias NPM.Lockfile

  defmodule Metadata do
    @moduledoc "Package signature stored beside a JS runtime installation."

    @derive {Jason.Encoder, only: [:signature, :packages]}
    defstruct signature: nil, packages: %{}
  end

  @spec install!(map(), keyword()) :: %{install_dir: String.t(), node_modules: String.t()}
  def install!(packages, opts \\ []) when is_map(packages) do
    Application.ensure_all_started(:req)

    source_lock = read_source_lock!(packages, opts[:lockfile])
    id = install_id(packages, source_lock)
    install_dir = Keyword.get(opts, :install_dir, default_install_dir(id))
    node_modules = Path.join(install_dir, "node_modules")
    lockfile_path = Path.join(install_dir, "npm.lock")
    metadata_path = Path.join(install_dir, "volt-runtime.json")
    signature = install_signature(packages, source_lock)

    with_lock(install_dir, fn ->
      if Keyword.get(opts, :force, false) or metadata_mismatch?(metadata_path, signature) do
        File.rm_rf!(install_dir)
      end

      unless install_intact?(lockfile_path, node_modules, metadata_path, signature) do
        File.mkdir_p!(install_dir)
        install_packages!(packages, source_lock, node_modules, lockfile_path)
        write_metadata!(metadata_path, signature, packages)
      end
    end)

    %{install_dir: install_dir, node_modules: node_modules}
  end

  defp install_packages!(packages, nil, node_modules, lockfile_path) do
    resolve_and_link!(packages, node_modules, lockfile_path)
  end

  defp install_packages!(_packages, source_lock, node_modules, lockfile_path) do
    File.cp!(source_lock.path, lockfile_path)
    link!(source_lock.packages, node_modules)
    warn_ignored_install_scripts(source_lock.packages)
  end

  defp resolve_and_link!(packages, node_modules, lockfile_path) do
    NPM.Resolver.clear_cache()

    case NPM.Resolver.resolve(packages) do
      {:ok, resolved} ->
        {nested, flat} = Map.pop(resolved, :nested, %{})

        lockfile =
          flat
          |> NPM.Install.LockfileBuilder.build(&ignore_age_warning/3)
          |> NPM.Install.NestedLockfile.add(nested, &ignore_age_warning/3)

        NPM.Lockfile.write(lockfile, lockfile_path)
        link!(lockfile, node_modules)
        warn_ignored_install_scripts(lockfile)

      {:error, message} ->
        raise "NPM package resolution failed:\n#{message}"
    end
  end

  defp link!(lockfile, node_modules) do
    case NPM.Install.Linker.link(lockfile, node_modules) do
      :ok -> :ok
      {:error, reason} -> raise "NPM package installation failed: #{inspect(reason)}"
    end
  end

  defp ignore_age_warning(_name, _version, _info), do: :ok

  defp warn_ignored_install_scripts(lockfile) do
    packages =
      lockfile
      |> Enum.filter(fn {_name, entry} -> Map.get(entry, :has_install_script, false) end)
      |> Enum.map(fn {name, entry} -> [name, "@", entry.version] end)
      |> Enum.intersperse(", ")
      |> IO.iodata_to_binary()

    if packages != "" do
      Logger.warning(
        "Volt ignored npm lifecycle scripts for #{packages}; npm_ex does not run install hooks"
      )
    end
  end

  defp install_intact?(lockfile_path, node_modules, metadata_path, signature) do
    with true <- metadata_matches?(metadata_path, signature),
         {:ok, policy} <- Lockfile.read_policy(lockfile_path),
         true <- Lockfile.policy_matches?(policy),
         {:ok, lockfile} when lockfile != %{} <- Lockfile.read(lockfile_path) do
      Enum.all?(lockfile, fn {name, _} ->
        File.exists?(Path.join([node_modules, name, "package.json"]))
      end)
    else
      _ -> false
    end
  end

  defp with_lock(id, fun) do
    :global.trans({__MODULE__, id}, fun, [node()], :infinity)
  end

  defp metadata_mismatch?(metadata_path, signature) do
    File.exists?(metadata_path) and not metadata_matches?(metadata_path, signature)
  end

  defp metadata_matches?(metadata_path, signature) do
    with {:ok, json} <- File.read(metadata_path),
         {:ok, decoded} <- Jason.decode(json) do
      match?(%{"signature" => ^signature}, decoded)
    else
      _ -> false
    end
  end

  defp write_metadata!(metadata_path, signature, packages) do
    metadata = %Metadata{signature: signature, packages: stringify_packages(packages)}
    File.write!(metadata_path, Jason.encode!(metadata))
  end

  defp read_source_lock!(_packages, nil), do: nil

  defp read_source_lock!(packages, path) when is_binary(path) do
    path = Path.expand(path)
    contents = File.read!(path)

    unless NPM.Lockfile.version(path) == 1 do
      raise ArgumentError, "expected npm lockfile version 1, got: #{inspect(path)}"
    end

    {:ok, policy} = NPM.Lockfile.read_policy(path)

    unless NPM.Lockfile.policy_matches?(policy) do
      raise ArgumentError,
            "npm lockfile security policy does not match current configuration: #{path}"
    end

    {:ok, lockfile} = NPM.Lockfile.read(path)
    validate_source_lock!(packages, lockfile, path)
    validate_lock_entries!(lockfile, lockfile, path)

    %{
      path: path,
      packages: lockfile,
      digest: :crypto.hash(:sha256, contents)
    }
  end

  defp read_source_lock!(_packages, path) do
    raise ArgumentError, "expected :lockfile to be a path, got: #{inspect(path)}"
  end

  defp validate_source_lock!(packages, lockfile, path) do
    Enum.each(packages, fn {name, version} ->
      case lockfile do
        %{^name => %{version: ^version}} ->
          :ok

        %{^name => %{version: locked_version}} ->
          raise ArgumentError,
                "npm lockfile version mismatch for #{name}: expected #{version}, got #{locked_version} in #{path}"

        _ ->
          raise ArgumentError, "npm lockfile is missing direct package #{name}: #{path}"
      end
    end)
  end

  defp validate_lock_entries!(entries, root_lockfile, path) do
    Enum.each(entries, fn {name, entry} ->
      if entry.integrity == "" or entry.tarball == "" do
        raise ArgumentError, "npm lockfile has incomplete package metadata for #{name}: #{path}"
      end

      NPM.Security.RegistryPolicy.validate_url!(entry.tarball)

      Enum.each(entry.dependencies, fn {dependency, requirement} ->
        nested_entry = Map.get(entry.nested_dependencies, dependency)
        root_entry = Map.get(root_lockfile, dependency)

        unless locked_requirement?(nested_entry, requirement) or
                 locked_requirement?(root_entry, requirement) do
          raise ArgumentError,
                "npm lockfile does not satisfy #{name} dependency #{dependency}@#{requirement}: #{path}"
        end
      end)

      validate_lock_entries!(entry.nested_dependencies, root_lockfile, path)
    end)
  end

  defp locked_requirement?(nil, _requirement), do: false

  defp locked_requirement?(entry, requirement) do
    NPMSemver.matches?(entry.version, requirement)
  rescue
    ArgumentError -> false
  end

  defp install_id(packages, source_lock), do: install_signature(packages, source_lock)

  defp install_signature(packages, nil) do
    packages
    |> Enum.sort()
    |> hash_install_signature()
  end

  defp install_signature(packages, source_lock) do
    packages
    |> Enum.sort()
    |> then(&{&1, source_lock.digest})
    |> hash_install_signature()
  end

  defp hash_install_signature(value) do
    value
    |> :erlang.term_to_binary()
    |> :erlang.md5()
    |> Base.encode16(case: :lower)
  end

  defp stringify_packages(packages) do
    Map.new(packages, fn {name, requirement} -> {to_string(name), to_string(requirement)} end)
  end

  defp default_install_dir(id) do
    root =
      System.get_env("VOLT_JS_RUNTIME_DIR") ||
        Path.join(NPM.Config.cache_dir(), "volt-js-runtimes")

    Path.join(root, id)
  end
end
