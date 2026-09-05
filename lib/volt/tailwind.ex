defmodule Volt.Tailwind do
  @moduledoc """
  Tailwind CSS build contexts backed by Oxide and QuickBEAM.

  Each CSS root/profile pair owns an isolated scanner and generated CSS state.
  This keeps incremental rebuilds independent across applications and profiles.
  """

  @default_key {:default, :inline}

  @spec build(keyword()) :: {:ok, String.t()} | {:error, term()}
  def build(opts \\ []) do
    opts
    |> worker()
    |> GenServer.call({:build, opts}, :infinity)
  end

  @spec rebuild([String.t() | map()], keyword()) ::
          {:ok, String.t()} | :unchanged | {:error, term()}
  def rebuild(changed_files, opts \\ []) do
    opts
    |> worker()
    |> GenServer.call({:rebuild, changed_files, opts}, :infinity)
  end

  defp worker(opts) do
    key = Keyword.get(opts, :key, @default_key)
    Volt.Tailwind.Supervisor.worker(key, sources: Keyword.get(opts, :sources, []))
  end
end
