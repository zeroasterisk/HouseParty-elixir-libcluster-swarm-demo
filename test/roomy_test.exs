defmodule RoomyTest do
  use ExUnit.Case
  doctest Roomy

  test "greets the world" do
    assert Roomy.hello() == :world
  end
end
