defmodule HousePartyPersonWorkerTest do
  use ExUnit.Case
  doctest HouseParty.PersonWorker

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  test "starts GenServer, unique named GenServer" do
    {:ok, pid_1} = HouseParty.PersonWorker.start_link(:test_person_1)
    {:ok, pid_2} = HouseParty.PersonWorker.start_link(:test_person_2)
    assert pid_1 != pid_2
    assert is_pid(pid_1) == true
    assert HouseParty.PersonWorker.stop(pid_1, :normal) == :ok
    assert HouseParty.PersonWorker.stop(pid_2, :normal) == :ok
    assert_down(pid_1)
    assert_down(pid_2)
  end
  # test "PersonWorker.log_entry will update current_room, count, and log of entered rooms" do
  #   {:ok, pid_1} = HouseParty.PersonWorker.start_link(:test_person_1)
  #   assert HouseParty.PersonWorker.log_entry(pid_1, :room_1) == :ok
  #   assert HouseParty.PersonWorker.log_entry(pid_1, :room_2) == :ok
  #   assert HouseParty.PersonWorker.log_entry(pid_1, :room_3) == :ok
  #   {:ok, %HouseParty.PersonWorker{
  #     current_room: current_room,
  #     count: count,
  #     log: log,
  #   } = _state} = pid_1 |> HouseParty.PersonWorker.dump()
  #   assert current_room == :room_3
  #   assert count == 3
  #   # can not easily check the timestamps, so omitting from assert
  #   rooms = log |> Enum.map(fn({_time, room, _action}) -> room end)
  #   assert rooms == [:room_3, :room_2, :room_1]
  #   actions = log |> Enum.map(fn({_time, _room, action}) -> action end)
  #   assert actions == [:entered, :entered, :entered]
  #
  #   assert HouseParty.PersonWorker.stop(pid_1, :normal) == :ok
  #   assert_down(pid_1)
  # end
end
