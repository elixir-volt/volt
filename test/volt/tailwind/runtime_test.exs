defmodule Volt.Tailwind.RuntimeTest do
  use ExUnit.Case, async: false

  test "one-shot compilation releases its linked runtime on success and compiler error" do
    {:links, before_links} = Process.info(self(), :links)
    before_links = MapSet.new(before_links)

    assert {:ok, css} =
             Volt.Tailwind.Runtime.compile_once("@tailwind utilities;", ["flex"], File.cwd!())

    assert css =~ ".flex"
    {:links, after_success} = Process.info(self(), :links)
    assert MapSet.new(after_success) == before_links

    assert {:error, _} =
             Volt.Tailwind.Runtime.compile_once(
               "@import './does-not-exist.css';",
               [],
               File.cwd!()
             )

    {:links, after_failure} = Process.info(self(), :links)
    assert MapSet.new(after_failure) == before_links
  end
end
