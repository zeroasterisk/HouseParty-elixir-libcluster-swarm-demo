defmodule RoomyTest do
  use ExUnit.Case
  doctest Roomy

  @doc """
  Common testing setup (copy/paste into iex)
  """
  def common_setup do
    Roomy.add_rooms([:kitchen, :living_room, :bedroom_king])
    Roomy.walk_into(:living_room, [:alan, :james, :lucy])
    Roomy.walk_into(:bedroom_king, [:james, :lucy, :jess])
  end
  def setup do
    Swarm.registered() |> Enum.map(fn({_name, pid}) -> GenServer.stop(pid) end)
  end

  test "build a house, by adding a list of rooms" do
    assert Roomy.add_rooms([:kitchen, :living_room, :bedroom_king]) == :ok
    assert Roomy.dump([:living_room, :bedroom_king]) == %{
      living_room: [],
      bedroom_king: [],
    }
  end
  test "walk into specific rooms, ensures idempotency" do
    assert Roomy.add_rooms([:kitchen, :living_room, :bedroom_king]) == :ok
    assert Roomy.walk_into(:living_room, [:alan, :james, :lucy]) == :ok
    assert Roomy.walk_into(:bedroom_king, [:james, :lucy, :jess]) == :ok
    assert Roomy.dump([:living_room, :bedroom_king]) == %{
      bedroom_king: [:james, :jess, :lucy],
      living_room: [:alan],
    }
  end
end


