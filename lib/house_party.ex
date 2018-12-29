
defmodule HouseParty do
  @moduledoc """
  Documentation for HouseParty.
  """
  require Logger
  alias HouseParty.PersonWorker
  alias HouseParty.RoomWorker

  @doc """
  Add rooms

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms()
      :ok

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms(:kitchen)
      :ok

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms([:kitchen, :living_room])
      :ok

  """
  def add_rooms(), do: :ok
  def add_rooms([]), do: :ok
  def add_rooms(rooms) when is_list(rooms), do: add_rooms(:ok, rooms)
  def add_rooms(room) when is_atom(room), do: add_rooms(:ok, [room])
  def add_rooms(_), do: {:error, "Invalid room argument"}
  # process all rooms in a loop, until empty or error
  def add_rooms(:ok, []), do: :ok
  def add_rooms(:ok, [room | rest]) do
    {status, _} = room |> add_room()
    status |> add_rooms(rest)
  end
  def add_rooms(:error, _list), do: :error


  # Add a room (not used externally)
  defp add_room(%RoomWorker{name: room_name} = room) when is_atom(room_name) do
    name = build_process_name(:room, room_name)
    name |> Swarm.register_name(RoomWorker, :start_link, [room]) |> add_room_finish()
  end
  defp add_room(room) when is_atom(room) do
    name = build_process_name(:room, room)
    name |> Swarm.register_name(RoomWorker, :start_link, [room]) |> add_room_finish()
  end
  # handle the output from Swarm.register_name and auto-join the group if possible
  defp add_room_finish({:ok, pid}) do
    {Swarm.join(:house_party_rooms, pid), pid}
  end
  defp add_room_finish({:error, {:already_registered, pid}}), do: {:ok, pid}
  defp add_room_finish(:error), do: add_room_finish({:error, "unknown reason"})
  defp add_room_finish({:error, reason}) do
    Logger.error("add_rooms() failure for #{reason}")
    {:error, reason}
  end


  @doc """
  Add people

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.add_people()
      :ok

      iex> HouseParty.reset()
      iex> HouseParty.add_people(:kitchen)
      :ok

      iex> HouseParty.reset()
      iex> HouseParty.add_people([:kitchen, :living_person])
      :ok

  """
  def add_people(), do: :ok
  def add_people([]), do: :ok
  def add_people(people) when is_list(people), do: add_people(:ok, people)
  def add_people(person) when is_atom(person), do: add_people(:ok, [person])
  def add_people(_), do: {:error, "Invalid person argument"}
  # process all people in a loop, until empty or error
  def add_people(:ok, []), do: :ok
  def add_people(:ok, [person | rest]) do
    {status, _} = person |> add_person()
    status |> add_people(rest)
  end
  def add_people(:error, _list), do: :error
  # Add a person (not used externally)
  defp add_person(%PersonWorker{name: person_name} = person) when is_atom(person_name) do
    name = build_process_name(:person, person_name)
    name |> Swarm.register_name(PersonWorker, :start_link, [person]) |> add_person_finish()
  end
  defp add_person(person) when is_atom(person) do
    name = build_process_name(:person, person)
    name |> Swarm.register_name(PersonWorker, :start_link, [person]) |> add_person_finish()
  end
  # handle the output from Swarm.register_name and auto-join the group if possible
  defp add_person_finish({:ok, pid}) do
    {Swarm.join(:house_party_people, pid), pid}
  end
  defp add_person_finish({:error, {:already_registered, pid}}), do: {:ok, pid}
  defp add_person_finish(:error), do: add_person_finish({:error, "unknown reason"})
  defp add_person_finish({:error, reason}) do
    Logger.error("add_people() failure for #{reason}")
    {:error, reason}
  end


  @doc """
  Get the current room for any person

  ## Examples

      iex> HousePartyTest.common_setup_tick1()
      iex> HouseParty.get_current_room(:play) |> HousePartyTest.end_tests()
      :den

  """
  def get_current_room(person) when is_atom(person) do
    HouseParty.dump()
    |> Enum.filter(fn({_room_name, people_in_room}) -> Enum.member?(people_in_room, person) end)
    |> Enum.map(fn({room_name, _people_in_room}) -> room_name end)
    |> List.first()
  end

  @doc """
  Get a single person's pid

  ## Examples

      iex> HousePartyTest.common_setup_tick1()
      iex> HouseParty.get_person_pid(:play) |> HousePartyTest.end_tests() |> is_pid()
      true

      iex> HouseParty.get_person_pid(nil)
      nil

  """
  def get_person_pid(nil), do: nil
  def get_person_pid(person_name) when is_atom(person_name) do
    typed_name = build_process_name(:person, person_name)
    house_party_pids = Swarm.members(:house_party_people)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.filter(fn({name, _pid}) -> name == typed_name end)
    |> Enum.map(fn({_name, pid}) -> pid end)
    |> List.first()
  end

  @doc """
  Get a single room's pid

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms([:kitchen])
      iex> HouseParty.get_room_pid(:kitchen) |> HousePartyTest.end_tests() |> is_pid()
      true

      iex> HouseParty.reset()
      iex> HouseParty.get_room_pid(nil)
      nil

  """
  def get_room_pid(nil), do: nil
  def get_room_pid(room_name) when is_atom(room_name) do
    typed_name = build_process_name(:room, room_name)
    house_party_pids = Swarm.members(:house_party_rooms)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.filter(fn({name, _pid}) -> name == typed_name end)
    |> Enum.map(fn({_name, pid}) -> pid end)
    |> List.first()
  end

  @doc """
  Get all room names

  ## Examples

      iex> HousePartyTest.common_setup_tick1()
      iex> HouseParty.get_all_rooms() |> HousePartyTest.end_tests()
      [:den, :kitchen, :living_room]

  """
  def get_all_rooms() do
    house_party_pids = Swarm.members(:house_party_rooms)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.map(fn({name, _pid}) -> name |> Atom.to_string() |> String.slice(5, 99) |> String.to_atom end)
    |> Enum.sort()
  end

  @doc """
  Get all person names

  ## Examples

      iex> HousePartyTest.common_setup_tick1()
      iex> HouseParty.get_all_people() |> HousePartyTest.end_tests()
      [:kid, :ladonna, :play, :sidney]

  """
  def get_all_people() do
    house_party_pids = Swarm.members(:house_party_people)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.map(fn({name, _pid}) -> name |> Atom.to_string() |> String.slice(7, 99) |> String.to_atom end)
    |> Enum.sort()
  end

  @doc """
  Dump people in all of the rooms

  We could list all rooms and dump each...
  but instead we are using `Swarm.multi_call`
  to get all processes dumps in parallel and aggregage them.

  ## Examples

      iex> HousePartyTest.common_setup_tick1()
      iex> HouseParty.dump() |> HousePartyTest.end_tests()
      %{living_room: [:kid], kitchen: [], den: [:ladonna, :play, :sidney]}
  """
  def dump() do
    :house_party_rooms
    |> Swarm.multi_call({:dump})
    |> Enum.sort_by(fn({:ok, {room_name, _}}) -> room_name end)
    |> Enum.reduce(%{}, fn({:ok, {room_name, people_in_room}}, acc) ->
      acc |> Map.put(room_name, people_in_room)
    end)
  end

  @doc """
  Who is in a room

  NOTE we could optimze by only dumping the room we need

  ## Examples

      iex> HousePartyTest.common_setup_tick1()
      iex> HouseParty.who_is_in(:living_room)
      [:kid]
  """
  def who_is_in(room_name) do
    dump() |> Map.get(room_name, [])
  end

  @doc """
  Where is a person

  ## Examples

      iex> HousePartyTest.common_setup_tick1()
      iex> HouseParty.where_is(:play)
      :den
  """
  def where_is(person_name) do
    dump()
    |> Enum.filter(fn({_room_name, people}) -> Enum.member?(people, person_name) end)
    |> Enum.map(fn({room_name, _people}) -> room_name end)
    |> List.first()
  end

  @doc """
  Dump person log

  ## Examples

      iex> HousePartyTest.common_setup_tick1()
      iex> HouseParty.get_person_room_log(:play) |> Enum.map(fn({_dt, room, _action}) -> room end)
      [:den, :living_room]
  """
  def get_person_room_log(person_name) do
    case person_name |> get_person_pid() |> PersonWorker.dump() do
      {:ok, %PersonWorker{log: log}} -> log
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create a process name for Swarm process registry

  This takes 2 atoms :type and :name and merges them into a single :type_name
  (could use anything to organize processes)

  ## Examples

      iex> HouseParty.build_process_name(:room, :den)
      :room_den
  """
  def build_process_name(type, name) do
    Atom.to_string(type) <> "_" <> Atom.to_string(name) |> String.to_atom()
  end

  @doc """
  Testing with Swarm is kinda tricky,
  because the doctest processes stay open and want to over-lap with eachother.

  This is basically a doctest_start function to trash all standing processes before a test
  """
  def reset() do
    Swarm.registered()
    |> Enum.map(fn({_name, pid}) ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)
  end

end
