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
    assert HouseParty.walk_into(:living_room, [:alan, :james, :lucy]) == :ok
    assert HouseParty.walk_into(:bedroom_king, [:james, :lucy, :jess]) == :ok
    assert HouseParty.dump() == %{
      bedroom_king: [:james, :jess, :lucy],
      living_room: [:alan],
      kitchen: [],
    }
    end_tests()
  end
end


