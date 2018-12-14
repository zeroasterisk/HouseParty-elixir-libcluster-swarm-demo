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
  def walk_into(room, person) do
    case leave(person) do
      :ok ->
        case HouseParty.RoomWorker.add_person(room, person) do
          :ok -> :ok
          :error -> {:error, "Unable to enter room #{room}"}
        end
      :error -> {:error, "Unable to enter room #{room}, could not leave first"}
    end
  end

  @doc """
  Remove a person from all rooms

  Drop the mix, I'm out!

  ## Examples

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:living_room, :james)
      iex> HouseParty.leave(:james)
      :ok

  """
  def leave(person) do
    get_all_rooms() |> HouseParty.RoomWorker.rm_person(person)
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
      iex> HouseParty.get_all_rooms()
      [:den, :hallway, :living_room, :kitchen]

  """
  def get_all_rooms() do
    house_party_pids = Swarm.members(__MODULE__)
    all_processes = Swarm.registered()
                    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
                    |> Enum.map(fn({name, _pid}) -> name end)
  end

  @doc """
  Dump information about some of the rooms

  ## Examples

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:kitchen, :alan)
      iex> HouseParty.walk_into(:living_room, :james)
      iex> HouseParty.dump([:living_room])
      %{living_room: [:james]}

  """
  def dump([], acc), do: acc
  def dump([room | rest], acc) do
    people = case HouseParty.RoomWorker.who_is_in(room) do
      {:ok, people} -> people
      {:error, reason} -> "ERROR: Unable to list room #{room}: #{reason}"
      :error -> "ERROR: Unable to enter room #{room} (unknown reason)"
    end
    dump(rest, Map.put(acc, room, people))
  end
  def dump(room, acc) when is_bitstring(room) or is_atom(room), do: dump([room], acc)
  def dump(room), do: dump(room, %{})

  @doc """
  Dump information about all of the rooms

  When you use `HouseParty.dump()` with no args, we list all people in all rooms.

  We could list all rooms and dump each...
  but we can also use `Swarm.multi_call` to get all processes dumps in parallel and aggregage them

  ## Examples

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:kitchen, :alan)
      iex> HouseParty.walk_into(:living_room, :james)
      iex> HouseParty.dump()
      %{kitchen: [:alan], living_room: [:james]}

      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:kitchen, :alan)
      iex> HouseParty.walk_into(:living_room, :james)
      iex> Swarm.multi_call(HouseParty, {:dump}) |> Enum.sort_by(fn({:ok, {room_name, _}}) -> room_name end)
      [
        ok: {:kitchen, MapSet.new([:alan])},
        ok: {:living_room, MapSet.new([:james])},
      ]

  """
  def dump() do
    __MODULE__
    |> Swarm.multi_call({:dump})
    |> Enum.sort_by(fn({:ok, {room_name, _}}) -> room_name end)
    |> Enum.reduce(%{}, fn({:ok, {room_name, people_in_room}}, acc) ->
      acc |> Map.put(room_name, MapSet.to_list(people_in_room))
    end)
  end
end
