defmodule Volt.Test.CaseTest do
  use Volt.Test.Case, async: false

  test "assert runs inline TypeScript sigil assertions" do
    assert ~TS"""
    type User = { name: string }

    const user: User = { name: 'Ada' }
    expect(user.name).toBe('Ada')
    """
  end

  test "assert preserves top-level imports" do
    dir = Path.join(System.tmp_dir!(), "volt-test-case-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "math.ts"), "export const answer = 42\n")

    on_exit(fn -> File.rm_rf!(dir) end)

    assert_js(
      ~TS"""
      import { answer } from 'case-math'

      expect(answer).toBe(42)
      """,
      bundle: [aliases: %{"case-math" => Path.join(dir, "math.ts")}]
    )
  end

  test "assert reports JavaScript assertion failures" do
    error =
      assert_raise ExUnit.AssertionError, fn ->
        assert ~TS"""
        expect(1 + 1).toBe(3)
        """
      end

    assert Exception.message(error) =~ "to be"
    assert Exception.message(error) =~ __ENV__.file
  end

  test "regular ExUnit assertions still work" do
    assert 1 + 1 == 2
    assert "volt" =~ "vo"
  end

  test "assert handles JSX and TSX sigils" do
    assert ~JSX"""
    expect('jsx').toContain('x')
    """

    assert ~TSX"""
    const value: string = 'tsx'
    expect(value).toContain('x')
    """
  end

  test "assert uses global Volt test config" do
    previous = Application.get_env(:volt, :test, [])
    runtime = Path.expand("fixtures/jsx-runtime.js", __DIR__)

    Application.put_env(:volt, :test, bundle: [aliases: %{"react/jsx-runtime" => runtime}])

    on_exit(fn -> Application.put_env(:volt, :test, previous) end)

    assert ~TSX"""
    const node = <button>Save</button>
    expect(node.props.children).toBe('Save')
    """
  end

  test "assert_js remains available explicitly" do
    assert_js(~JS"""
    expect('volt').toContain('vo')
    """)
  end
end

defmodule Volt.Test.CaseJSXTest do
  use Volt.Test.Case,
    async: false,
    bundle: [
      aliases: %{
        "react/jsx-runtime" => Path.expand("fixtures/jsx-runtime.js", __DIR__)
      }
    ]

  test "assert bundles JSX runtime imports" do
    assert ~JSX"""
    const node = <div data-name="volt" />
    expect(node.props['data-name']).toBe('volt')
    """

    assert ~TSX"""
    const node = <span data-count={1} />
    expect(node.props['data-count']).toBe(1)
    """
  end
end

defmodule Volt.Test.CaseBrowserTest do
  use Volt.Test.Case, async: false, browser: true

  test "assert can run in a browser" do
    assert ~TS"""
    document.body.innerHTML = '<button>Save</button>'

    expect(document.querySelector('button')?.textContent).toBe('Save')
    """
  end
end
