defmodule HousePartyRoomWorkerTest do
  use ExUnit.Case
  doctest HouseParty.RoomWorker

  test "starts GenServer, unique named GenServer" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    {:ok, pid_2} = HouseParty.RoomWorker.start_link(:test_room_2)
    assert pid_1 != pid_2
    assert is_pid(pid_1) == true
    :ok = HouseParty.RoomWorker.stop(pid_1, :normal)
    :ok = HouseParty.RoomWorker.stop(pid_2, :normal)
  end
  test "starts GenServer, add people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    :ok = HouseParty.RoomWorker.add_person(pid_1, :person_2)
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_2]
    # auto-sorted because it's a MapSet under the hood
    :ok = HouseParty.RoomWorker.add_person(pid_1, :person_1)
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    # auto-idempotent because it's a MapSet under the hood
    :ok = HouseParty.RoomWorker.add_person(pid_1, :person_1)
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    :ok = HouseParty.RoomWorker.stop(pid_1, :normal)
  end
  test "starts GenServer, add list of people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    :ok = HouseParty.RoomWorker.add_person(pid_1, [:person_1, :person_2])
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    :ok = HouseParty.RoomWorker.stop(pid_1, :normal)
  end
  test "starts GenServer, add and remove people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    :ok = HouseParty.RoomWorker.add_person(pid_1, [:person_1, :person_2])
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    :ok = HouseParty.RoomWorker.rm_person(pid_1, :person_2)
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1]
    :ok = HouseParty.RoomWorker.stop(pid_1, :normal)
  end
  test "starts GenServer, add and remove list of people" do
    {:ok, pid_1} = HouseParty.RoomWorker.start_link(:test_room_1)
    :ok = HouseParty.RoomWorker.add_person(pid_1, [:person_1, :person_2])
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == [:person_1, :person_2]
    :ok = HouseParty.RoomWorker.rm_person(pid_1, [:person_1, :person_2])
    {:ok, people} = HouseParty.RoomWorker.who_is_in(pid_1)
    assert people == []
    :ok = HouseParty.RoomWorker.stop(pid_1, :normal)
  end
end
