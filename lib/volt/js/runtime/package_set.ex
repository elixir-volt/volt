defmodule Volt.JS.Runtime.PackageSet do
  @moduledoc false

  alias Volt.JS.Runtime.Installer

  @enforce_keys [:app, :name, :packages]
  defstruct [:app, :name, :packages]

  @type t :: %__MODULE__{
          app: atom(),
          name: atom(),
          packages: %{required(String.t()) => String.t()}
        }

  @spec bundled(atom(), atom(), map()) :: t()
  def bundled(app, name, packages)
      when is_atom(app) and is_atom(name) and is_map(packages) do
    %__MODULE__{app: app, name: name, packages: packages}
  end

  @spec install!(t(), keyword()) :: %{install_dir: String.t(), node_modules: String.t()}
  def install!(%__MODULE__{} = set, opts \\ []) do
    Installer.install!(set.packages, lock_opts(set, opts))
  end

  @spec runtime_opts(t(), keyword()) :: keyword()
  def runtime_opts(%__MODULE__{} = set, opts \\ []) do
    set
    |> lock_opts(opts)
    |> Keyword.put(:packages, set.packages)
  end

  @spec lockfile_path(t()) :: String.t()
  def lockfile_path(%__MODULE__{app: app, name: name}) do
    Volt.Priv.path({app, "npm"}, "#{name}.lock")
  end

  defp lock_opts(set, opts) do
    lockfile = lockfile_path(set)
    opts = opts |> Keyword.delete(:packages) |> Keyword.delete(:lockfile)

    if use_bundled_lock?(lockfile) do
      Keyword.put(opts, :lockfile, lockfile)
    else
      opts
    end
  end

  defp use_bundled_lock?(lockfile) do
    case NPM.Lockfile.read_policy(lockfile) do
      {:ok, policy} when is_map(policy) -> NPM.Lockfile.policy_matches?(policy)
      _ -> true
    end
  end
end
