defmodule Volt.Tailwind.ArtifactTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  test "replaces the stylesheet without leaving temporary files", %{tmp_dir: tmp} do
    assert :ok = Volt.Tailwind.Artifact.write(tmp, "site", "first")
    assert :ok = Volt.Tailwind.Artifact.write(tmp, "site", "second")

    assert File.read!(Path.join(tmp, "site.css")) == "second"
    assert File.ls!(tmp) == ["site.css"]
  end

  test "accepts disabled output",
    do: assert(:ok = Volt.Tailwind.Artifact.write(nil, "site", "css"))
end
