defmodule RoomyTest do
  use ExUnit.Case
  doctest Roomy

  test "build a house, by adding a list of rooms" do
    assert Roomy.add_rooms([:kitchen, :living_room, :bedroom_king]) == :ok
    assert Roomy.dump([:living_room, :bedroom_king]) == %{
      living_room: [],
      bedroom_king: [],
    }
  end
  test "walk into specific rooms, ensures idempotency" do
    assert Roomy.add_rooms([:kitchen, :living_room, :bedroom_king]) == :ok
    assert Roomy.walk_into(:living_room, [:alan, :james, :george]) == :ok
    assert Roomy.walk_into(:bedroom_king, [:james, :george]) == :ok
    assert Roomy.dump([:living_room, :bedroom_king]) == %{
      living_room: [:alan],
      bedroom_king: [:george, :james],
    }
  end
end
