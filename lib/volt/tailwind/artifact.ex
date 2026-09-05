defmodule Volt.Tailwind.Artifact do
  @moduledoc false

  @spec write(String.t() | nil, String.t(), String.t()) :: :ok
  def write(nil, _name, _css), do: :ok

  def write(outdir, name, css) do
    File.mkdir_p!(outdir)
    path = Path.join(outdir, "#{name}.css")
    temporary = path <> ".#{System.unique_integer([:positive])}.tmp"

    with :ok <- File.write(temporary, css),
         :ok <- File.rename(temporary, path) do
      :ok
    else
      {:error, reason} ->
        File.rm(temporary)
        raise File.Error, reason: reason, action: "write", path: path
    end
  end
end
