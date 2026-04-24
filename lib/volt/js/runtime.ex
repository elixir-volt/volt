defmodule Volt.JS.Runtime do
  @moduledoc """
  Runs JavaScript build tools through QuickBEAM with package dependencies isolated
  from the user's application.
  """

  alias Volt.JS.Runtime.Bundler
  alias Volt.JS.Runtime.Entry
  alias Volt.JS.Runtime.Error
  alias Volt.JS.Runtime.Installer

  defstruct [:name, :pid, :install_dir, :node_modules, :packages, :entry]

  @type t :: %__MODULE__{
          name: GenServer.name() | nil,
          pid: pid(),
          install_dir: String.t(),
          node_modules: String.t(),
          packages: map(),
          entry: String.t() | nil
        }

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    id = Keyword.get(opts, :id) || Keyword.get(opts, :name) || __MODULE__

    %{
      id: id,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    case start(opts) do
      {:ok, %__MODULE__{pid: pid}} -> {:ok, pid}
      {:error, _} = error -> error
    end
  end

  @spec start(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def start(opts) do
    with {:ok, runtime} <- prepare_runtime(opts),
         {:ok, pid} <- start_quickbeam(opts, runtime) do
      {:ok, %{runtime | pid: pid}}
    end
  end

  @spec ensure!(keyword()) :: t()
  def ensure!(opts) do
    case Keyword.get(opts, :name) do
      nil ->
        start!(opts)

      name ->
        case GenServer.whereis(name) do
          pid when is_pid(pid) -> runtime_for_existing(name, pid, opts)
          nil -> start!(opts)
        end
    end
  end

  @spec call(t() | GenServer.server(), String.t(), list(), keyword()) :: QuickBEAM.js_result()
  def call(runtime, function, args \\ [], opts \\ [])

  def call(%__MODULE__{pid: pid}, function, args, opts) do
    QuickBEAM.call(pid, function, args, opts)
  end

  def call(runtime, function, args, opts) do
    QuickBEAM.call(runtime, function, args, opts)
  end

  @spec stop(t() | GenServer.server()) :: :ok
  def stop(%__MODULE__{pid: pid}), do: QuickBEAM.stop(pid)
  def stop(runtime), do: QuickBEAM.stop(runtime)

  @spec package_path!(t(), String.t()) :: String.t()
  def package_path!(%__MODULE__{node_modules: node_modules}, package) do
    path = Path.join(node_modules, package)

    if File.exists?(path) do
      path
    else
      raise "Package #{inspect(package)} is not installed in #{node_modules}"
    end
  end

  @spec node_modules!(t()) :: String.t()
  def node_modules!(%__MODULE__{node_modules: node_modules}), do: node_modules

  defp start!(opts) do
    case start(opts) do
      {:ok, runtime} -> runtime
      {:error, error} -> raise error
    end
  end

  defp runtime_for_existing(name, pid, opts) do
    packages = Keyword.get(opts, :packages, %{})
    install = Installer.install!(packages, opts)
    runtime_struct(opts, packages, install, pid) |> Map.put(:name, name)
  end

  defp prepare_runtime(opts) do
    packages = Keyword.get(opts, :packages, %{})
    install = Installer.install!(packages, opts)
    runtime = runtime_struct(opts, packages, install, nil)
    entry = materialize_entry(opts, runtime)
    {:ok, %{runtime | entry: entry}}
  rescue
    exception ->
      {:error,
       Error.exception(
         stage: :prepare,
         reason: exception,
         message: Exception.message(exception)
       )}
  end

  defp start_quickbeam(opts, runtime) do
    define = build_define(opts, runtime)

    quickbeam_opts =
      opts
      |> Keyword.take([
        :name,
        :apis,
        :memory_limit,
        :max_stack_size,
        :max_convert_depth,
        :max_convert_nodes
      ])
      |> maybe_put(:script, runtime.entry)
      |> Keyword.put(:handlers, build_handlers(opts, runtime))
      |> Keyword.put(:define, define)

    case QuickBEAM.start(quickbeam_opts) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, Error.exception(stage: :start, reason: reason)}
    end
  end

  defp runtime_struct(opts, packages, install, pid) do
    %__MODULE__{
      name: Keyword.get(opts, :name),
      pid: pid,
      install_dir: install.install_dir,
      node_modules: install.node_modules,
      packages: packages
    }
  end

  defp materialize_entry(opts, runtime) do
    case Keyword.fetch(opts, :entry) do
      {:ok, entry} ->
        path = Entry.materialize(entry, runtime.install_dir)

        if Keyword.get(opts, :bundle, false) do
          bundle_entry!(path, runtime)
        else
          path
        end

      :error ->
        nil
    end
  end

  defp bundle_entry!(path, runtime) do
    bundle_path = bundle_cache_path(path, runtime)

    if File.regular?(bundle_path) do
      bundle_path
    else
      case Bundler.bundle_file(path, node_modules: runtime.node_modules) do
        {:ok, code} when is_binary(code) ->
          write_bundle!(bundle_path, code)

        {:ok, %{code: code}} when is_binary(code) ->
          write_bundle!(bundle_path, code)

        {:error, reason} ->
          raise Error,
            stage: :bundle,
            reason: reason,
            message: "Could not bundle JS runtime entry #{inspect(path)}: #{inspect(reason)}"
      end
    end
  end

  defp bundle_cache_path(path, runtime) do
    source = File.read!(path)

    hash =
      :crypto.hash(:sha256, :erlang.term_to_binary({source, runtime.packages}))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    filename = Path.basename(path, Path.extname(path)) <> "-" <> hash <> ".js"
    Path.join([runtime.install_dir, "runtime", "bundles", filename])
  end

  defp write_bundle!(path, code) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, code)
    path
  end

  defp build_handlers(opts, runtime) do
    handlers = Keyword.get(opts, :handlers, %{})
    if is_function(handlers, 1), do: handlers.(runtime), else: handlers
  end

  defp build_define(opts, runtime) do
    define = Keyword.get(opts, :define, %{})

    define = if is_function(define, 1), do: define.(runtime), else: define

    Map.merge(
      %{
        "VOLT_JS_RUNTIME_ROOT" => runtime.install_dir,
        "VOLT_NODE_MODULES" => runtime.node_modules
      },
      define
    )
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
