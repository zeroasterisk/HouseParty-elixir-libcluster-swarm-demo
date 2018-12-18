defmodule HousePartyTest do
  use ExUnit.Case
  doctest HouseParty

  @doc """
  Common testing setup (copy/paste into iex)
  """
  def common_setup do
    HouseParty.add_rooms([:kitchen, :living_room, :bedroom_king])
    HouseParty.walk_into(:living_room, [:kid, :play, :sidney])
    HouseParty.walk_into(:bedroom_king, [:play, :sidney, :ladonna])
  end
  def setup do
    on_exit fn ->
      end_tests()
    end
  end
  def end_tests(output \\ :ok) do
    Swarm.registered()
    |> Enum.each(fn({_name, pid}) ->
      GenServer.stop(pid)
      assert_down(pid)
    end)
    output
  end
  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
  test "build a house, by adding a list of rooms" do
    assert HouseParty.add_rooms([:kitchen, :living_room, :bedroom_king]) == :ok
    assert HouseParty.dump() == %{
      bedroom_king: [],
      living_room: [],
      kitchen: [],
    }
    end_tests()
  end
  test "walk into specific rooms, ensures idempotency" do
    assert HouseParty.add_rooms([:kitchen, :living_room, :bedroom_king]) == :ok
    assert HouseParty.walk_into(:living_room, [:kid, :play, :sidney]) == :ok
    assert HouseParty.walk_into(:bedroom_king, [:play, :ladonna, :sidney]) == :ok
    assert HouseParty.dump() == %{
      bedroom_king: [:ladonna, :play, :sidney],
      living_room: [:kid],
      kitchen: [],
    }
    end_tests()
  end
  test "ensure we can only walk into a room, up to max people, people stay in their room" do
    assert HouseParty.add_rooms([:kitchen, :living_room]) == :ok
    assert HouseParty.walk_into(:kitchen, 1..9 |> Enum.map(fn(i) -> String.to_atom("cook_#{i}") end)) == :ok
    assert HouseParty.walk_into(:living_room, 1..9 |> Enum.map(fn(i) -> String.to_atom("rando_#{i}") end)) == :ok
    init_dump = HouseParty.dump()
    # no new people from outside
    assert HouseParty.walk_into(:kitchen, :cook_10) == {:error, :destination_full}
    assert HouseParty.dump() == init_dump
    # no moving people from old room to new room (stays in old)
    assert HouseParty.walk_into(:kitchen, :rando_1) == {:error, :destination_full}
    assert HouseParty.dump() == init_dump

    end_tests()
  end
end


