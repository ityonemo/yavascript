defmodule YavascriptTest.BunTest do
  use ExUnit.Case

  use Yavascript,
    engine: Yavascript.BunEngine,
    setup: :setup_js,
    import: [my_function: 2],
    script: """
      const my_function = (a, b) => a + b;
    """

  test "you can run javascript" do
    setup_js()
    assert 3 == my_function(1, 2)
    assert "foobar" == my_function("foo", "bar")
  end
end
