defmodule Volt.Builder.PublicationTest do
  use ExUnit.Case, async: true

  alias Volt.Builder.{Artifact, Plan, Publication}
  @moduletag :tmp_dir

  test "rejects destination symlinks before replacing any files", %{tmp_dir: root} do
    outdir = Path.join(root, "output")
    outside = Path.join(root, "outside")
    File.mkdir_p!(outdir)
    File.mkdir_p!(outside)
    File.write!(Path.join(outdir, "app.js"), "previous")
    File.ln_s!(outside, Path.join(outdir, "linked"))

    {:ok, plan} =
      Plan.new([
        %Artifact{file: "app.js", content: "replacement"},
        %Artifact{file: "linked/escape.js", content: "escape"}
      ])

    assert {:error, {:symlink_destination, _}} = Publication.write(outdir, plan)
    assert File.read!(Path.join(outdir, "app.js")) == "previous"
    assert File.ls!(outside) == []
  end

  test "staging failure leaves existing output unchanged", %{tmp_dir: root} do
    outdir = Path.join(root, "output")
    File.mkdir_p!(outdir)
    File.write!(Path.join(outdir, "app.js"), "previous")
    # A file/directory conflict is a deterministic failure without permission assumptions.
    plan = %Plan{
      artifacts: [
        %Artifact{file: "app.js", content: "replacement"},
        %Artifact{file: "nested", content: "file"},
        %Artifact{file: "nested/child.js", content: "child"}
      ]
    }

    assert {:error, {:staging_failed, "nested/child.js", _}} = Publication.write(outdir, plan)
    assert File.read!(Path.join(outdir, "app.js")) == "previous"
    assert File.ls!(root) == ["output"]
  end

  test "commit failure does not replace manifest", %{tmp_dir: root} do
    outdir = Path.join(root, "output")
    File.mkdir_p!(Path.join(outdir, "blocked.js"))
    File.write!(Path.join(outdir, "manifest.json"), "previous")

    {:ok, plan} =
      Plan.new([
        %Artifact{file: "blocked.js", content: "next"},
        %Artifact{file: "manifest.json", content: "next manifest"}
      ])

    assert {:error, {:publication_failed, "blocked.js", _}} = Publication.write(outdir, plan)
    assert File.read!(Path.join(outdir, "manifest.json")) == "previous"
    assert File.ls!(root) == ["output"]
  end

  test "successful publication preserves unrelated static files", %{tmp_dir: root} do
    File.write!(Path.join(root, "robots.txt"), "keep")
    {:ok, plan} = Plan.new([%Artifact{file: "app.js", content: "new"}])
    assert :ok = Publication.write(root, plan)
    assert File.read!(Path.join(root, "robots.txt")) == "keep"
    assert File.read!(Path.join(root, "app.js")) == "new"
  end
end
