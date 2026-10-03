defmodule Volt.HMR.DocumentTest do
  use ExUnit.Case, async: true

  alias Volt.HMR.Document

  defp page(body, head \\ "") do
    "<html><head><title>t</title>#{head}</head><body>#{body}</body></html>"
  end

  describe "changes/3" do
    test "patches changes to content" do
      assert Document.changes(page("<p>one</p>"), page("<p class=\"x\">two</p>"), nil) ==
               {:patch, %{owned: [], root: %{}, head: %{remove: [], add: []}}}
    end

    test "patches data blocks, which the browser does not run" do
      before = page(~s(<script type="application/json">{"a":1}</script>))
      now = page(~s(<script type="application/json">{"a":2}</script>))

      assert Document.changes(before, now, nil) ==
               {:patch, %{owned: [], root: %{}, head: %{remove: [], add: []}}}
    end

    test "reloads when the scripts the page runs differ" do
      before = page(~s(<script type="module" src="/app.ts"></script>))

      assert Document.changes(before, page(~s(<script type="module" src="/b.ts"></script>)), nil) ==
               :reload

      assert Document.changes(page("<script>a()</script>"), page("<script>b()</script>"), nil) ==
               :reload

      assert Document.changes(before, page(""), nil) == :reload
    end

    test "reloads when the stylesheets differ" do
      link = ~s(<link rel="stylesheet" href="/a.css">)

      assert Document.changes(
               page("", link),
               page("", ~s(<link rel="stylesheet" href="/b.css">)),
               nil
             ) ==
               :reload

      assert Document.changes(page("", "<style>a{}</style>"), page("", "<style>b{}</style>"), nil) ==
               :reload
    end

    test "names the owned elements whose attributes the server changed" do
      before =
        page(
          ~s(<div data-island="a" data-props="1"></div><div data-island="b" data-props="1"></div>)
        )

      now =
        page(
          ~s(<div data-island="a" data-props="1"></div><div data-island="b" data-props="2"></div>)
        )

      assert {:patch, %{owned: owned}} = Document.changes(before, now, "[data-island]")
      assert owned == [%{index: 1, attributes: %{"data-island" => "b", "data-props" => "2"}}]
    end

    test "names the attributes the server changed on html and body" do
      before =
        ~s(<html lang="en" data-a="1"><head></head><body class="old"><p>x</p></body></html>)

      now =
        ~s(<html lang="ru"><head></head><body class="old" data-route="/x"><p>x</p></body></html>)

      assert {:patch, %{root: root}} = Document.changes(before, now, nil)

      assert root == %{
               "html" => %{set: %{"lang" => "ru"}, remove: ["data-a"]},
               "body" => %{set: %{"data-route" => "/x"}, remove: []}
             }
    end

    test "names the head elements that are gone and that are new" do
      before =
        page("", ~s(<meta name="description" content="old"><link rel="icon" href="/i.png">))

      now = page("", ~s(<meta name="description" content="new"><link rel="icon" href="/i.png">))

      assert {:patch, %{head: head}} = Document.changes(before, now, nil)

      assert head == %{
               remove: [~s(<meta name="description" content="old"/>)],
               add: [~s(<meta name="description" content="new"/>)]
             }
    end

    test "reloads when owned elements are added or removed" do
      before = page(~s(<div data-island="a"></div>))

      assert Document.changes(before, page(""), "[data-island]") == :reload
    end
  end
end
