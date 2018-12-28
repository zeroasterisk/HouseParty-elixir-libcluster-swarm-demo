defmodule HousePartyTest do
  use ExUnit.Case
  doctest HouseParty

  @doc """
  Common testing setup (copy/paste into iex)
  """
  def common_setup do
    HouseParty.reset()
    HouseParty.add_rooms([:kitchen, :living_room, :den])
    HouseParty.add_people([:kid, :play, :sidney, :ladonna])
  end
  def common_setup_tick1 do
    common_setup()
    :kid |> HouseParty.get_person_pid() |> HouseParty.PersonWorker.walk_into(:living_room)
    :play |> HouseParty.get_person_pid() |> HouseParty.PersonWorker.walk_into(:living_room)
    :sidney |> HouseParty.get_person_pid() |> HouseParty.PersonWorker.walk_into(:living_room)
    :play |> HouseParty.get_person_pid() |> HouseParty.PersonWorker.walk_into(:den)
    :sidney |> HouseParty.get_person_pid() |> HouseParty.PersonWorker.walk_into(:den)
    :ladonna |> HouseParty.get_person_pid() |> HouseParty.PersonWorker.walk_into(:den)
  end
  def setup do
    HouseParty.reset()
    on_exit fn -> end_tests() end
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

  test "build a house, by adding a list of rooms and people outside" do
    assert HouseParty.add_rooms([:kitchen, :living_room, :den]) == :ok
    assert HouseParty.add_people([:kid, :play, :sidney, :ladonna]) == :ok
    assert HouseParty.dump() == %{
      den: [],
      living_room: [],
      kitchen: [],
    }
    end_tests()
  end
  test "walk into specific rooms, ensures idempotency" do
    common_setup_tick1()
    assert HouseParty.dump() == %{
      den: [:ladonna, :play, :sidney],
      living_room: [:kid],
      kitchen: [],
    }
    end_tests()
  end
  test "get_current_room for a person" do
    common_setup_tick1()
    assert HouseParty.get_current_room(:kid) == :living_room
    end_tests()
  end
  test "get_person_pid for a person" do
    common_setup_tick1()
    person_pid = HouseParty.get_person_pid(:kid)
    assert is_pid(person_pid)
    end_tests()
  end
  test "get_room_pid for a room" do
    common_setup_tick1()
    room_pid = HouseParty.get_room_pid(:den)
    assert is_pid(room_pid)
    end_tests()
  end
end


