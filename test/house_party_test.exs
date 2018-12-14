defmodule HousePartyTest do
  use ExUnit.Case
  doctest HouseParty

  @doc """
  Common testing setup (copy/paste into iex)
  """
  def common_setup do
    HouseParty.add_rooms([:kitchen, :living_room, :bedroom_king])
    HouseParty.walk_into(:living_room, [:alan, :james, :lucy])
    HouseParty.walk_into(:bedroom_king, [:james, :lucy, :jess])
  end
  def setup do
    Swarm.registered() |> Enum.map(fn({_name, pid}) -> GenServer.stop(pid) end)
  end

  test "build a house, by adding a list of rooms" do
    assert HouseParty.add_rooms([:kitchen, :living_room, :bedroom_king]) == :ok
    assert HouseParty.dump([:living_room, :bedroom_king]) == %{
      living_room: [],
      bedroom_king: [],
    }
  end
  test "walk into specific rooms, ensures idempotency" do
    assert HouseParty.add_rooms([:kitchen, :living_room, :bedroom_king]) == :ok
    assert HouseParty.walk_into(:living_room, [:alan, :james, :lucy]) == :ok
    assert HouseParty.walk_into(:bedroom_king, [:james, :lucy, :jess]) == :ok
    assert HouseParty.dump([:living_room, :bedroom_king]) == %{
      bedroom_king: [:james, :jess, :lucy],
      living_room: [:alan],
    }
  end
end


