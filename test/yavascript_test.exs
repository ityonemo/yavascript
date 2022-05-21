defmodule YavascriptTest do
  use ExUnit.Case
  doctest Yavascript

  test "greets the world" do
    assert Yavascript.hello() == :world
  end
end
