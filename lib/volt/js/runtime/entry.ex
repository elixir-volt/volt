defmodule Volt.JS.Runtime.Entry do
  @moduledoc false

  @spec materialize(term(), String.t()) :: String.t()
  def materialize({:volt_asset, filename}, install_dir) do
    filename
    |> Volt.JS.Asset.path_for()
    |> copy_to_runtime_dir(install_dir)
  end

  def materialize({:priv, app, path}, install_dir) when is_atom(app) do
    app
    |> :code.priv_dir()
    |> to_string()
    |> Path.join(path)
    |> copy_to_runtime_dir(install_dir)
  end

  def materialize({:path, path}, install_dir), do: copy_to_runtime_dir(path, install_dir)

  def materialize({:source, source, filename}, install_dir)
      when is_binary(source) and is_binary(filename) do
    path = runtime_path(install_dir, filename, source)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, source)
    path
  end

  def materialize(path, install_dir) when is_binary(path),
    do: copy_to_runtime_dir(path, install_dir)

  defp copy_to_runtime_dir(path, install_dir) do
    source = File.read!(path)
    target = runtime_path(install_dir, Path.basename(path), source)
    File.mkdir_p!(Path.dirname(target))
    File.write!(target, source)
    target
  end

  defp runtime_path(install_dir, filename, source) do
    hash = :crypto.hash(:sha256, source) |> Base.encode16(case: :lower) |> binary_part(0, 12)
    Path.join([install_dir, "runtime", hash <> "-" <> filename])
  end
end
