
defmodule HouseParty.WalkIntoProc do
  @moduledoc """
  Process struct for HouseParty.walk_into, ensures a simple chain of actions in the process
  """
  defstruct [
    status_add: nil,
    status_rm: nil,
    status_log: nil,
    current_room: nil,
    current_room_pid: nil,
    person: nil,
    person_pid: nil,
    room: nil,
    room_pid: nil,
  ]
end


defmodule HouseParty do
  @moduledoc """
  Documentation for HouseParty.
  """
  require Logger
  alias HouseParty.PersonWorker
  alias HouseParty.RoomWorker
  alias HouseParty.WalkIntoProc

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
  def add_rooms(room) when is_bitstring(room) or is_atom(room), do: add_rooms(:ok, [room])
  def add_rooms(_), do: {:error, "Invalid room argument"}
  # process all rooms in a loop, until empty or error
  def add_rooms(:ok, []), do: :ok
  def add_rooms(:ok, [room | rest]) when is_atom(room) do
    {status, _} = room |> add_room()
    status |> add_rooms(rest)
  end
  def add_rooms(:error, _list), do: :error


  # Add a room (not used externally)
  defp add_room(room) when is_bitstring(room), do: room |> String.to_atom() |> add_room()
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


  # Add a person (not used externally)
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
    Logger.error("add_person() failure for #{reason}")
    {:error, reason}
  end


  @doc """
  Walk into a room, add a person to a room

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:living_room, :peanut) |> HousePartyTest.end_tests()
      :ok

  """
  # loop through people when people are a list
  def walk_into(:ok, _room, []), do: :ok
  def walk_into({:error, reason}, _room, _people), do: {:error, reason}
  def walk_into(:ok, room, [person | rest]), do: room |> walk_into(person) |> walk_into(room, rest)
  def walk_into(room, people) when is_list(people), do: :ok |> walk_into(room, people)
  # handle a single person
  def walk_into(room, person) when is_bitstring(room), do: walk_into(String.to_atom(room), person)
  def walk_into(room, person) when is_bitstring(person), do: walk_into(room, String.to_atom(person))
  def walk_into(room, person) when is_atom(room) and is_atom(person) do
    %WalkIntoProc{
      person: person,
      room: room,
    } |> walk_into()
  end
  # no status?  run the walk_into process
  def walk_into(%WalkIntoProc{status_add: nil, status_rm: nil, status_log: nil} = acc) do
    acc
    |> walk_into_lookup()
    |> walk_into_start_room_process()
    |> walk_into_start_person_process()
    |> walk_into_add_person()
    |> walk_into_rm_person()
    |> walk_into_log()
    # |> IO.inspect()
    |> walk_into_summarize()
  end

  # lookup current_room & existing PIDs if possible
  defp walk_into_lookup(%WalkIntoProc{person: person, room: room} = acc) when is_atom(room) and is_atom(person) do
    current_room = get_current_room(person)
    acc |> Map.merge(%{
      current_room: current_room,
      current_room_pid: get_room_pid(current_room),
      person: person,
      person_pid: get_person_pid(person),
      room: room,
      room_pid: get_room_pid(room),
    })
  end

  # start a person process
  defp walk_into_start_person_process(%WalkIntoProc{person_pid: person_pid} = acc) when is_pid(person_pid) do
    # person already started, no-op
    acc
  end
  defp walk_into_start_person_process(%WalkIntoProc{person: person} = acc) when is_atom(person) do
    case add_person(person) do
      {:ok, person_pid} -> acc |> Map.put(:person_pid, person_pid)
      {:error, {:already_registered, person_pid}} -> acc |> Map.put(:person_pid, person_pid)
      {:error, _reason} -> acc |> Map.put(:status_add, {:error, :unable_to_setup_person})
    end
  end

  # start a room process
  defp walk_into_start_room_process(%WalkIntoProc{room_pid: room_pid} = acc) when is_pid(room_pid) do
    # room already started, no-op
    acc
  end
  defp walk_into_start_room_process(%WalkIntoProc{room: room} = acc) when is_atom(room) do
    case add_room(room) do
      {:ok, room_pid} -> acc |> Map.put(:room_pid, room_pid)
      {:error, {:already_registered, room_pid}} -> acc |> Map.put(:room_pid, room_pid)
      {:error, _reason} -> acc |> Map.put(:status_add, {:error, :unable_to_setup_room})
    end
  end

  # add a person to room
  defp walk_into_add_person(%WalkIntoProc{room: room, current_room: current_room} = acc) when current_room == room do
    # same room?  no-op
    acc |> Map.put(:status_add, :skip)
  end
  defp walk_into_add_person(%WalkIntoProc{person: person, room_pid: room_pid} = acc) when is_atom(person) and is_pid(room_pid) do
    acc |> Map.put(:status_add, RoomWorker.add_person(room_pid, person))
  end

  # remove from old room
  defp walk_into_rm_person(%WalkIntoProc{status_add: :skip} = acc) do
    acc |> Map.put(:status_rm, :skip)
  end
  defp walk_into_rm_person(%WalkIntoProc{status_add: :full} = acc) do
    acc |> Map.put(:status_rm, :skip)
  end
  defp walk_into_rm_person(%WalkIntoProc{status_add: :ok, current_room: nil, current_room_pid: nil} = acc) do
    acc |> Map.put(:status_rm, :ok) # no need to rm, but do need to log
  end
  defp walk_into_rm_person(%WalkIntoProc{status_add: :ok, person: person, current_room_pid: current_room_pid} = acc) do
    acc |> Map.put(:status_rm, RoomWorker.rm_person(current_room_pid, person))
  end

  # log the entry into the Person's process
  defp walk_into_log(%WalkIntoProc{status_add: :ok, person_pid: person_pid, room: room} = acc) do
    acc |> Map.put(:status_log, PersonWorker.enter(person_pid, room))
  end
  defp walk_into_log(%WalkIntoProc{} = acc) do
    acc |> Map.put(:status_log, :skip)
  end

  # summarize the walk_into statuses and out a single status --> :ok
  defp walk_into_summarize(%WalkIntoProc{status_add: :ok, status_rm: :ok, status_log: :ok}), do: :ok
  defp walk_into_summarize(%WalkIntoProc{status_add: :skip}), do: :ok # skip means same room, it's ok
  defp walk_into_summarize(%WalkIntoProc{status_add: :full}), do: {:error, :destination_full}
  defp walk_into_summarize(%WalkIntoProc{status_add: status}), do: {:error, "Unable to walk into room #{status}"}


  @doc """
  Get the current room for any person

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:living_room, :peanut)
      iex> HouseParty.get_current_room(:peanut) |> HousePartyTest.end_tests()
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

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:living_room, :peanut)
      iex> HouseParty.leave(:peanut) |> HousePartyTest.end_tests()
      :ok

  """
  def leave(person) when is_atom(person) do
    person
    |> get_current_room()
    |> get_room_pid()
    |> RoomWorker.rm_person(person)
  end

  @doc """
  Get a single person's pid

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms([:kitchen])
      iex> HouseParty.walk_into(:kitchen, :play)
      iex> HouseParty.get_person_pid(:play) |> HousePartyTest.end_tests() |> is_pid()
      true

      iex> HouseParty.reset()
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

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms([:kitchen, :den])
      iex> HouseParty.get_all_rooms() |> HousePartyTest.end_tests()
      [:den, :kitchen]

  """
  def get_all_rooms() do
    house_party_pids = Swarm.members(:house_party_rooms)
    Swarm.registered()
    |> Enum.filter(fn({_name, pid}) -> Enum.member?(house_party_pids, pid) end)
    |> Enum.map(fn({name, _pid}) ->
      name |> Atom.to_string() |> String.slice(5, 99) |> String.to_atom
    end)
  end

  @doc """
  Dump people in all of the rooms

  We could list all rooms and dump each...
  but instead we are using `Swarm.multi_call`
  to get all processes dumps in parallel and aggregage them.

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.add_rooms([:kitchen, :living_room])
      iex> HouseParty.walk_into(:kitchen, :bilal)
      iex> HouseParty.walk_into(:living_room, :peanut)
      iex> HouseParty.dump() |> HousePartyTest.end_tests()
      %{kitchen: [:bilal], living_room: [:peanut]}
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

      iex> HouseParty.reset()
      iex> HouseParty.walk_into(:kitchen, :bilal)
      iex> HouseParty.who_is_in(:kitchen)
      [:bilal]
  """
  def who_is_in(room_name) do
    dump() |> Map.get(room_name, [])
  end

  @doc """
  Where is a person

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.walk_into(:kitchen, :bilal)
      iex> HouseParty.where_is(:bilal)
      :kitchen
  """
  def where_is(person_name) do
    dump()
    |> Enum.filter(fn({_room_name, people}) -> Enum.member?(people, person_name) end)
    |> Enum.map(fn({room_name, _people}) -> room_name end)
    |> List.first()
  end

  @doc """
  Dump person log

  NOTE uses datetime entries, so difficult to doctest nicely:

      HouseParty.walk_into(:kitchen, :kid)
      HouseParty.walk_into(:den, :kid)
      HouseParty.walk_into(:bathroom, :kid)
      HouseParty.walk_into(:den, :kid)
      HouseParty.get_person_room_log(:kid)
      [
        {#DateTime<2018-12-18 05:34:34.928962Z>, :den},
        {#DateTime<2018-12-18 05:34:34.928467Z>, :bathroom},
        {#DateTime<2018-12-18 05:34:34.927777Z>, :den},
        {#DateTime<2018-12-18 05:34:34.927067Z>, :kitchen}
      ]

  ## Examples

      iex> HouseParty.reset()
      iex> HouseParty.walk_into(:kitchen, :kid)
      iex> HouseParty.walk_into(:den, :kid)
      iex> HouseParty.walk_into(:bathroom, :kid)
      iex> HouseParty.walk_into(:den, :kid)
      iex> HouseParty.get_person_room_log(:kid) |> Enum.map(fn({_dt, room}) -> room end)
      [
        :den,
        :bathroom,
        :den,
        :kitchen
      ]
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
