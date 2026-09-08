defmodule Volt.PublicDir do
  @moduledoc """
  Optional Vite-style public directory support.

  Phoenix apps normally serve stable public files from `priv/static` through
  `Plug.Static`, so this feature is disabled by default. When enabled for Vite
  compatibility, files in the configured public directory are served from the
  site root in development and copied as-is to the production static root. They
  are not transformed, hashed, or included in the module graph, so application
  code should reference them with root-absolute URLs such as `/favicon.svg`.
  """

  @doc """
  Returns the expanded public directory path, or `nil` when disabled.
  """
  @spec resolve(String.t() | false | nil) :: String.t() | nil
  def resolve(false), do: nil
  def resolve(nil), do: nil
  def resolve(path), do: Path.expand(path)

  @doc """
  Copies all files from `public_dir` into `static_root`.

  Missing public directories are ignored. Existing files at the destination are
  overwritten, matching the usual behavior of build output generation.
  """
  @spec copy(String.t() | nil, String.t()) :: :ok
  def copy(nil, _static_root), do: :ok

  def copy(public_dir, static_root) do
    if File.dir?(public_dir) do
      public_dir
      |> files()
      |> Enum.each(&copy_file(&1, public_dir, static_root))
    end

    :ok
  end

  @doc "Read public files into artifacts relative to the static root without copying them."
  def prepare(nil), do: []

  def prepare(public_dir) do
    if File.dir?(public_dir) do
      Enum.map(files(public_dir), fn path ->
        %Volt.Builder.Artifact{
          file: Path.relative_to(path, public_dir),
          content: File.read!(path)
        }
      end)
    else
      []
    end
  end

  @doc "Combine asset output and public files in a validated static-root plan."
  def prepare_output(plan, outdir, public_dir, publication_root) do
    outdir = Path.expand(outdir)
    static_root = Path.expand(publication_root)
    prefix = Path.relative_to(outdir, static_root)

    if outdir == static_root or Volt.Path.inside?(outdir, static_root) do
      assets =
        Enum.map(plan.artifacts, fn artifact ->
          if prefix == ".",
            do: artifact,
            else: %{artifact | file: Path.join(prefix, artifact.file)}
        end)

      with {:ok, combined} <- Volt.Builder.Plan.new(assets ++ prepare(public_dir)) do
        {:ok, static_root, combined}
      end
    else
      {:error, {:invalid_publication_root, static_root, outdir}}
    end
  end

  @doc """
  Resolves a root-relative request path inside `public_dir`.

  Returns `nil` for missing files, directories, disabled public directories, or
  paths that would escape the public directory.
  """
  @spec lookup(String.t() | nil, String.t()) :: String.t() | nil
  def lookup(nil, _request_path), do: nil

  def lookup(public_dir, request_path) do
    relative = request_path |> String.trim_leading("/") |> URI.decode()
    path = Path.expand(relative, public_dir)

    if inside?(path, public_dir) and File.regular?(path), do: path
  end

  defp files(public_dir) do
    public_dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reject(&File.dir?/1)
  end

  defp copy_file(path, public_dir, static_root) do
    relative = Path.relative_to(path, public_dir)
    dest = Path.join(static_root, relative)
    File.mkdir_p!(Path.dirname(dest))
    File.cp!(path, dest)
  end

  defp inside?(path, root), do: path == root or String.starts_with?(path, root <> "/")
end
