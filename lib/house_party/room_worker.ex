defmodule HouseParty.RoomWorker do
  use GenServer
  require Logger
  @moduledoc """
  This is the worker process, in this case,
  It is responsible for a single room in our house.
  It maintains state on who is in that room.
  #
  # can recieve a [room_name] or [room_name, people_in_room]
  """
  def start_link(room_name), do: start_link(room_name, [])
  def start_link(room_name, people_in_room) when is_atom(people_in_room), do: start_link(room_name, [people_in_room])
  def start_link(room_name, people_in_room) when is_list(people_in_room) do
    GenServer.start_link(__MODULE__, [room_name, people_in_room], [
      # used for name registration for GenServer
      name: room_name,
      timeout: 10_000
    ])
  end

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
  #
  # can recieve a [room_name] or [room_name, people_in_room]
  def init([room_name, people_in_room]) when is_list(people_in_room) do
    {:ok, {room_name, MapSet.new(people_in_room)}}
  end

  # dump the current state of this room: {room_name, people_in_room}
  def handle_call({:dump}, _from, state) do
    {:reply, {:ok, state}, state}
  end

  # who is in this room right now? return a simple list of people
  def handle_call({:who_is_in}, _from, {_room_name, people_in_room} = state) do
    {:reply, {:ok, people_in_room |> MapSet.to_list()}, state}
  end

  # we add a person to this room (not in scope, removal from other rooms)
  def handle_call({:add_person, people}, _from, {room_name, people_in_room}) when is_list(people) do
    people_in_room = people_in_room |> MapSet.union(MapSet.new(people))
    {:reply, :ok, {room_name, people_in_room}}
  end
  def handle_call({:add_person, person}, _from, {room_name, people_in_room}) do
    people_in_room = people_in_room |> MapSet.put(person)
    {:reply, :ok, {room_name, people_in_room}}
  end

  # we remove a person from this room
  def handle_call({:rm_person, people}, _from, {room_name, people_in_room}) when is_list(people) do
    people_in_room = people_in_room |> MapSet.difference(MapSet.new(people))
    {:reply, :ok, {room_name, people_in_room}}
  end
  def handle_call({:rm_person, person}, _from, {room_name, people_in_room}) do
    people_in_room = people_in_room |> MapSet.delete(person)
    {:reply, :ok, {room_name, people_in_room}}
  end

  # called when a handoff has been initiated due to changes
  # in cluster topology, valid response values are:
  #
  #   - `:restart`, to simply restart the process on the new node
  #   - `{:resume, state}`, to hand off some state to the new process
  #   - `:ignore`, to leave the process running on its current node
  #
  def handle_call({:swarm, :begin_handoff}, _from, {room_name, people_in_room}) do
    {:reply, {:resume, {room_name, people_in_room}}, {room_name, people_in_room}}
  end
  # called after the process has been restarted on its new node,
  # and the old process' state is being handed off. This is only
  # sent if the return to `begin_handoff` was `{:resume, state}`.
  # **NOTE**: This is called *after* the process is successfully started,
  # so make sure to design your processes around this caveat if you
  # wish to hand off state like this.
  def handle_cast({:swarm, :end_handoff, people_in_room}, {room_name, _}) do
    {:noreply, {room_name, people_in_room}}
  end
  # called when a network split is healed and the local process
  # should continue running, but a duplicate process on the other
  # side of the split is handing off its state to us. You can choose
  # to ignore the handoff state, or apply your own conflict resolution
  # strategy
  def handle_cast({:swarm, :resolve_conflict, other_node_state}, {room_name, people_in_room} = state) do
    Logger.debug("Room: #{room_name} contains: #{inspect(people_in_room)} got a resolve_conflict message from other node #{inspect(other_node_state)}")
    {:noreply, state}
  end

  # this message is sent when this process should die
  # because it is being moved, use this as an opportunity
  # to clean up
  def handle_info({:swarm, :die}, {room_name, people_in_room} = state) do
    # should do cleanup...?  maybe swarm will auto-move?
    Logger.debug("Room: #{room_name} contains: #{inspect(people_in_room)} got :swarm :die")
    {:stop, :shutdown, state}
  end
  def handle_info(:timeout, {room_name, people_in_room} = state) do
    Logger.debug("Room: #{room_name} contains: #{inspect(people_in_room)} got :timeout")
    {:stop, :shutdown, state}
  end

  # we can also remove as a cast, in the background/async
  def handle_cast(:rm_person, person, {room_name, people_in_room}) do
    people_in_room = people_in_room |> MapSet.delete(person)
    {:noreply, {room_name, people_in_room}}
  end

  # we don't really need a loop, but sometimes it's useful to see...
  # def handle_info(:loop, {room_name, people_in_room}) do
  #   Logger.debug("Room: #{room_name} contains: #{inspect(people_in_room)}")
  #   Process.send_after(self(), :loop, people_in_room)
  #   {:noreply, {room_name, people_in_room}}
  # end

end
