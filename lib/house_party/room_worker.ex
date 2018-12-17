defmodule HouseParty.RoomWorker do
  use GenServer
  alias HouseParty.RoomWorker
  require Logger
  @moduledoc """
  This is the worker process, in this case,
  It is responsible for a single room in our house.
  It maintains state on who is in that room.
  """

  defstruct [
    name: nil, # atom
    max: 10, # int, max people in room
    people: %{}, # MapSet of list of people in rooms as [atom]
  ]

  # helpers to convert into atom
  defp to_atom(str) when is_atom(str), do: str
  defp to_atom(str) when is_bitstring(str), do: String.to_atom(str)
  # helpers to convert into MapSet(atom, ...)
  defp to_atom_mapset(str) when is_atom(str), do: [str] |> to_atom_mapset()
  defp to_atom_mapset(str) when is_bitstring(str), do: [str] |> to_atom_mapset()
  defp to_atom_mapset(str) when is_list(str), do: str |> Enum.map(&to_atom/1) |> MapSet.new()
  defp to_atom_mapset(str) when is_map(str), do: str |> Enum.values() |> Enum.map(&to_atom/1) |> MapSet.new()


  @doc """
  Easy API to start a room worker
  """
  def start_link(name) when is_bitstring(name) or is_atom(name), do: start_link(%RoomWorker{name: name})
  def start_link(%RoomWorker{name: name} = state) when is_bitstring(name) do
    state |> Map.put(:name, String.to_atom(name)) |> start_link()
  end
  def start_link(%RoomWorker{people: people} = state) when is_list(people) do
    state |> Map.put(:people, to_atom_mapset(people)) |> start_link()
  end
  def start_link(%RoomWorker{name: name} = state) do
    GenServer.start_link(__MODULE__, state, [timeout: 10_000])
    # we could name the processes, pinning them to the atom of the room name
    # but doing so does not rely on the Swarm and is not multi-node.
    # GenServer.start_link(__MODULE__, state, [name: name, timeout: 10_000])
  end
  def start_link(%{} = state), do: %RoomWorker{} |> Map.merge(state) |> start_link()

  @doc """
  Stop
  """
  def stop(pid, reason \\ :normal), do: GenServer.stop(pid, reason)

  @doc """
  Who is in this room (list)
  """
  def who_is_in(pid), do: GenServer.call(pid, {:who_is_in})

  @doc """
  Add a person to this room
  """
  def add_person([], person), do: :ok
  def add_person([pid | rest], person) do
    case add_person(pid, person) do
      :ok -> add_person(rest, person)
      :full -> :full
      :error -> :error
    end
  end
  def add_person(pid, person), do: GenServer.call(pid, {:add_person, person})

  @doc """
  Remove a person from this room
  """
  def rm_person([], person), do: :ok
  def rm_person([pid | rest], person) do
    case rm_person(pid, person) do
      :ok -> rm_person(rest, person)
      :error -> :error
    end
  end
  def rm_person(pid, person), do: GenServer.call(pid, {:rm_person, person})


  # initialize the GenServer to maintain the state of the application
  def init(%RoomWorker{people: people} = state) do
    {:ok, state |> Map.put(:people, MapSet.new(people))}
  end

  # dump the current state of this room: {name, people}
  def handle_call({:dump}, _from, state) do
    out = {state.name, state.people |> MapSet.to_list()}
    {:reply, {:ok, out}, state}
  end

  # who is in this room right now? return a simple list of people
  def handle_call({:who_is_in}, _from, %RoomWorker{people: people} = state) do
    {:reply, {:ok, people |> MapSet.to_list()}, state}
  end

  # we add a person to this room (not in scope, removal from other rooms)
  def handle_call({:add_person, new_people}, _from, %RoomWorker{people: people, max: max} = state) do
    people = people |> MapSet.union(to_atom_mapset(new_people))
    if Enum.count(people) < max do
      {:reply, :ok, state |> Map.put(:people, people)}
    else
      {:reply, :full, state}
    end
  end

  # we remove a person from this room
  def handle_call({:rm_person, del_people}, _from, %RoomWorker{people: people} = state) do
    people = people |> MapSet.difference(to_atom_mapset(del_people))
    {:reply, :ok, state |> Map.put(:people, people)}
  end

  # called when a handoff has been initiated due to changes
  # in cluster topology, valid response values are:
  #
  #   - `:restart`, to simply restart the process on the new node
  #   - `{:resume, state}`, to hand off some state to the new process
  #   - `:ignore`, to leave the process running on its current node
  #
  def handle_call({:swarm, :begin_handoff}, _from, state) do
    Logger.debug(fn() -> ":swarm :begin_handoff #{inspect(state)}" end)
    {:reply, {:resume, state}, state}
  end
  # called after the process has been restarted on its new node,
  # and the old process' state is being handed off. This is only
  # sent if the return to `begin_handoff` was `{:resume, state}`.
  # **NOTE**: This is called *after* the process is successfully started,
  # so make sure to design your processes around this caveat if you
  # wish to hand off state like this.
  def handle_cast({:swarm, :end_handoff, state}, init_state) do
    Logger.debug(fn() -> ":swarm :end_handoff #{inspect(state)}" end)
    {:noreply, state}
  end
  # called when a network split is healed and the local process
  # should continue running, but a duplicate process on the other
  # side of the split is handing off its state to us. You can choose
  # to ignore the handoff state, or apply your own conflict resolution
  # strategy
  def handle_cast({:swarm, :resolve_conflict, other_node_state}, state) do
    Logger.debug(fn() -> ":swarm :resolve_conflict #{inspect(state)} got a resolve_conflict message from other node #{inspect(other_node_state)}" end)
    {:noreply, state}
  end

  # this message is sent when this process should die
  # because it is being moved, use this as an opportunity
  # to clean up
  def handle_info({:swarm, :die}, %RoomWorker{name: name, people: people} = state) do
    # should do cleanup...?  maybe swarm will auto-move?
    Logger.debug(fn() -> "Room: #{name} contains: #{inspect(people)} got :swarm :die" end)
    {:stop, :shutdown, state}
  end
  def handle_info(:timeout, %RoomWorker{name: name, people: people} = state) do
    Logger.debug(fn() -> "Room: #{name} contains: #{inspect(people)} got :timeout" end)
    {:stop, :shutdown, state}
  end

end
