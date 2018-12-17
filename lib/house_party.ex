defmodule HouseParty do
  @moduledoc """
  Documentation for HouseParty.
  """
  require Logger

  @doc """
  Add rooms

  ## Examples

      iex> HouseParty.add_rooms()
      :ok

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      :ok

  """
  def add_rooms(), do: :ok
  def add_rooms([]), do: :ok
  def add_rooms([room | rest]) when is_bitstring(room), do: add_rooms([String.to_atom(room) | rest])
  def add_rooms([room | rest]) when is_atom(room) do
    # NOTE process started with libswarm
    #      needed for the all_rooms in leave
    #      also for process distrobution in hostess
    # HouseParty.RoomWorker.start_link(room) |> add_rooms_finish()
    room |> Swarm.register_name(HouseParty.RoomWorker, :start_link, [room]) |> add_rooms_finish()
    add_rooms(rest)
  end
  def add_rooms(room) when is_bitstring(room) or is_atom(room), do: add_rooms([room])
  def add_rooms(_), do: {:error, "Invalid room argument"}

  # handle the output from Swarm.register_name ane auto-join the group if possible
  defp add_rooms_finish({:ok, pid}), do: Swarm.join(__MODULE__, pid)
  defp add_rooms_finish({:error, {:already_registered, _pid}}), do: :ok
  defp add_rooms_finish(:error), do: add_rooms_finish({:error, "unknown reason"})
  defp add_rooms_finish({:error, reason}) do
    Logger.error("add_rooms() failure for #{reason}")
    {:error, reason}
  end

  @doc """
  Walk into a room, add a person to a room

  ## Examples

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:living_room, :james)
      :ok

  """
  # loop through people when people are a list
  def walk_into(:ok, _room, []), do: :ok
  def walk_into({:error, reason}, _room, _people), do: {:error, reason}
  def walk_into(:ok, room, [person | rest]), do: room |> walk_into(person) |> walk_into(room, rest)
  def walk_into(room, people) when is_list(people), do: :ok |> walk_into(room, people)
  # handle a single person
  def walk_into(%{room: room, current_room: current_room}) when current_room == room, do: :ok
  def walk_into(%{
    current_room: nil,
    current_room_pid: nil,
    person: person,
    room: room,
    room_pid: room_pid,
  }) do
    # enter the new room
    case HouseParty.RoomWorker.add_person(room_pid, person) do
      :ok -> :ok
      :full ->
        # can not enter - the new room was full
        {:error, :destination_full}
    end
  end
  def walk_into(%{
    current_room: current_room,
    current_room_pid: current_room_pid,
    person: person,
    room: room,
    room_pid: room_pid,
  }) do
    # enter the new room
    case HouseParty.RoomWorker.add_person(room_pid, person) do
      :ok ->
        # leave the old room
        HouseParty.RoomWorker.rm_person(current_room_pid, person)
      :full ->
        # can not leave/enter - the new room was full
        {:error, :destination_full}
    end
  end
  def walk_into(room, person) when is_bitstring(room), do: walk_into(String.to_atom(room), person)
  def walk_into(room, person) when is_bitstring(person), do: walk_into(room, String.to_atom(person))
  def walk_into(room, person) when is_atom(room) and is_atom(person) do
    current_room = get_current_room(person)
    %{
      current_room: current_room,
      current_room_pid: get_room_pid(current_room),
      person: person,
      room: room,
      room_pid: get_room_pid(room),
    } |> walk_into()
  end

  @doc """
  Get the current room for any person

  ## Examples

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:living_room, :james)
      iex> HouseParty.get_current_room(:james)
      :living_room

  """
  def get_current_room(person) when is_atom(person) do
    HouseParty.dump()
    |> Enum.filter(fn({_room_name, people_in_room}) -> Enum.member?(people_in_room, person) end)
    |> Enum.map(fn({room_name, _people_in_room}) -> room_name end)
    |> List.first()
  end

  @doc """
  Remove a person from current_room

  Drop the mic, I'm out!

  ## Examples

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:living_room, :james)
      iex> HouseParty.leave(:james)
      :ok

  """
  def leave(person) when is_atom(person) do
    person
    |> get_current_room()
    |> get_room_pid()
    |> HouseParty.RoomWorker.rm_person(person)
  end

  @doc """
  Get a list of all of the rooms

  We first get a list of all `Swarm.members(HouseParty)` as [pid, ...]

  Next get a list of all `Swarm.registered` processes as [name: pid, ...]

  Then we return only the Swarm.registered process names which are part of the HouseParty group.
  (we may use Swarm to start other types of processes as well)

  ## Examples

      iex> Swarm.registered() |> Enum.map(fn({_name, pid}) -> GenServer.stop(pid) end)
      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.add_rooms([:hallway, :den])
      iex> HouseParty.get_all_rooms() |> HousePartyTest.end_tests()
      [:den, :hallway, :living_room, :kitchen]

  """
  def get_all_rooms() do
    house_party_pids = Swarm.members(__MODULE__)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.map(fn({name, _pid}) -> name end)
  end

  @doc """
  Get a single room's pid

  ## Examples

      iex> Swarm.registered() |> Enum.map(fn({_name, pid}) -> GenServer.stop(pid) end)
      iex> HouseParty.add_rooms([:kitchen])
      iex> HouseParty.get_room_pid(:kitchen) |> HousePartyTest.end_tests() |> is_pid()
      true

      iex> HouseParty.get_room_pid(nil)
      nil

  """
  def get_room_pid(nil), do: nil
  def get_room_pid(room_name) when is_atom(room_name) do
    house_party_pids = Swarm.members(__MODULE__)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.filter(fn({name, _pid}) -> name == room_name end)
    |> Enum.map(fn({_name, pid}) -> pid end)
    |> List.first()
  end

  @doc """
  Dump people in all of the rooms

  We could list all rooms and dump each...
  but instead we are using `Swarm.multi_call`
  to get all processes dumps in parallel and aggregage them.

  ## Examples

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:kitchen, :alan)
      iex> HouseParty.walk_into(:living_room, :james)
      iex> HouseParty.dump()
      %{kitchen: [:alan], living_room: [:james]}
  """
  def dump() do
    __MODULE__
    |> Swarm.multi_call({:dump})
    |> Enum.sort_by(fn({:ok, {room_name, _}}) -> room_name end)
    |> Enum.reduce(%{}, fn({:ok, {room_name, people_in_room}}, acc) ->
      acc |> Map.put(room_name, people_in_room)
    end)
  end
end
