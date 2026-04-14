defmodule Volt.WorkerRewriterTest do
  use ExUnit.Case, async: true

  test "returns source when no worker rewrites apply" do
    source =
      "const worker = new Worker(new URL('./worker.ts', import.meta.url), { type: 'module' })"

    {:ok, result} = Volt.WorkerRewriter.rewrite(source, "test.ts", fn _ -> :keep end)

    assert result == source
  end
end
