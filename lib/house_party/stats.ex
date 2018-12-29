defmodule HouseParty.Stats do
  alias HouseParty.PersonWorker
  alias HouseParty.RoomWorker
  require Logger
  @moduledoc """
  This is a collection of tools to gather and display stats about the processes currently in effect
  """

  @doc """
  Show bare minimum stats for
  """
  def tldr() do
    tldr_gather() |> tldr_simplify()
    # |> Enum.sort()
  end
  def tldr_simplify(%{} = stats) do
    stats
    |> Map.merge(%{
      avg_wanderlust_completion: Float.round(Map.get(stats, :person_count, 0) / Map.get(stats, :person_max, 1) * 100, 1),
      avg_fullness: Float.round(Map.get(stats, :room_count, 0) / Map.get(stats, :room_max, 1) * 100, 1),
    })
    |> Map.drop([:person_count, :person_max, :room_count, :room_max])
  end
  def tldr_gather() do
    people_pids = Swarm.members(:house_party_people)
    room_pids = Swarm.members(:house_party_rooms)
    Swarm.registered()
    |> Enum.reduce(%{}, fn({name, pid}, acc) ->
      tldr_reducer({name, pid}, acc, people_pids, room_pids)
    end)
    |> Map.put(:total_people, Enum.count(people_pids))
    |> Map.put(:total_rooms, Enum.count(room_pids))
  end
  def tldr_reducer({name, pid}, %{} = acc, people_pids, room_pids) do
    cond do
      Enum.member?(people_pids, pid) ->
        {:ok, state} = PersonWorker.take(pid, [:count, :max, :current_room])
        key = tldr_reducer_key(pid, state)
        acc
        |> Map.put(key, Map.get(acc, key, 0) + 1)
        |> Map.merge(%{
          person_max: Map.get(acc, :person_max, 0) + state.max,
          person_count: Map.get(acc, :person_count, 0) + state.count,
        })
      Enum.member?(room_pids, pid) ->
        {:ok, state} = RoomWorker.take(pid, [:count, :max])
        # key = tldr_reducer_key(pid, state)
        acc
        # |> Map.put(key, Map.get(acc, key, 0) + 1)
        |> Map.merge(%{
          room_max: Map.get(acc, :room_max, 0) + state.max,
          room_count: Map.get(acc, :room_count, 0) + state.count,
        })
      true -> acc
    end
  end
  def tldr_reducer_key(pid, %{current_room: nil}) do
    :people_waiting_to_enter_party
  end
  def tldr_reducer_key(pid, %{current_room: :left_party}) do
    :people_left_party
  end
  def tldr_reducer_key(pid, %{current_room: current_room}) do
    # TODO people on node
    # TODO people in rooms
    # String.to_atom("people_in_" <> Atom.to_string(current_room))
    :people_in_rooms
  end
  def tldr_reducer_key(pid, %RoomWorker{}) do
    # TODO rooms on nodes
    :total_rooms_active
  end

end
