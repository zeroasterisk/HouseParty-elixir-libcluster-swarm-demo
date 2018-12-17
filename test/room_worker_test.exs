defmodule HousePartyRoomWorkerTest do
  use ExUnit.Case
  doctest HouseParty.RoomWorker

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  test "starts GenServer, unique named GenServer" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    {:ok, pid_2} = HouseParty.RoomWorker.start_link(:test_room_2)
    assert pid_1 != pid_2
    assert is_pid(pid_1) == true
    assert HouseParty.RoomWorker.stop(pid_1, :normal) == :ok
    assert HouseParty.RoomWorker.stop(pid_2, :normal) == :ok
    assert_down(pid_1)
    assert_down(pid_2)
  end
  test "starts GenServer, add people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    assert HouseParty.RoomWorker.add_person(pid_1, :person_2) == :ok
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_2]
    # auto-sorted because it's a MapSet under the hood
    assert HouseParty.RoomWorker.add_person(pid_1, :person_1) == :ok
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    # auto-idempotent because it's a MapSet under the hood
    assert HouseParty.RoomWorker.add_person(pid_1, :person_1) == :ok
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    assert HouseParty.RoomWorker.stop(pid_1, :normal) == :ok
    assert_down(pid_1)
  end
  test "starts GenServer, add list of people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    assert HouseParty.RoomWorker.add_person(pid_1, [:person_1, :person_2]) == :ok
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    assert HouseParty.RoomWorker.stop(pid_1, :normal) == :ok
    assert_down(pid_1)
  end
  test "starts GenServer, add and remove people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    assert HouseParty.RoomWorker.add_person(pid_1, [:person_1, :person_2]) == :ok
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    assert HouseParty.RoomWorker.rm_person(pid_1, :person_2) == :ok
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1]
    assert HouseParty.RoomWorker.stop(pid_1, :normal) == :ok
    assert_down(pid_1)
  end
  test "starts GenServer, add and remove list of people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    assert HouseParty.RoomWorker.add_person(pid_1, [:person_1, :person_2]) == :ok
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    assert HouseParty.RoomWorker.rm_person(pid_1, [:person_1, :person_2]) == :ok
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == []
    assert HouseParty.RoomWorker.stop(pid_1, :normal) == :ok
    assert_down(pid_1)
  end
  test "ensure we can only add up to max people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(%{
      name: :test_room_1,
      max: 3,
      people: [:one, :two, :three],
    })
    assert HouseParty.RoomWorker.add_person(pid_1, [:four]) == :full
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:one, :three, :two]
    assert HouseParty.RoomWorker.stop(pid_1, :normal) == :ok
    assert_down(pid_1)
  end
end
