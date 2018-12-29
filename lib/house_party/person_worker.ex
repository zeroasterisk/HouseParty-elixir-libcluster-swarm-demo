defmodule HouseParty.PersonWorker do
  use GenServer
  alias HouseParty.PersonWorker
  require Logger
  @moduledoc """
  This is the worker process for a Person, in this case,
  It is responsible for a single person in our house.
  It maintains a log for what rooms a person has entered.
  """
  @timeout :infinity

  defstruct [
    name: nil, # atom
    current_room: nil, # nil = not yet entered, :left_party = gone, or a room name
    count: 0, # how many rooms person has entered
    max: 100, # how many rooms until person leaves
    wander_delay_ms: 1000, # when wandering, move rooms after this delay (in ms)
    log: [], # [{<time>, <room>}, ...]
  ]

  @doc """
  Easy API to start a person worker
  """
  def start_link(name) when is_atom(name), do: start_link(%PersonWorker{name: name})
  def start_link(%PersonWorker{name: name} = state) when is_atom(name) do
    GenServer.start_link(__MODULE__, state, [timeout: @timeout])
  end

  @doc """
  Stop
  """
  def stop(pid, reason \\ :normal), do: GenServer.stop(pid, reason)

  @doc """
  Dump details about the person
  """
  def dump(pid), do: GenServer.call(pid, {:dump})

  @doc """
  Dump raw state for the person
  """
  def dump_state(pid), do: GenServer.call(pid, {:dump_state})

  @doc """
  take fields from the state
  """
  def take(pid, fields), do: GenServer.call(pid, {:take, fields})

  @doc """
  Log entering a room
  """
  def walk_into(pid, room) when is_pid(pid) and is_atom(room), do: GenServer.call(pid, {:walk_into, room})

  @doc """
  Start wander-loop, until done wandering
  """
  def wanderlust(pid), do: GenServer.call(pid, {:wanderlust})

  # initialize the GenServer to maintain the state of the application
  def init(%PersonWorker{} = state) do
    {:ok, state}
  end

  # dump the current state of this person
  def handle_call({:dump}, _from, state) do
    out = state
    {:reply, {:ok, out}, state}
  end

  # dump the current state (unaltered)
  def handle_call({:dump_state}, _from, state) do
    {:reply, {:ok, state}, state}
  end

  # take fields from the state
  def handle_call({:take, fields}, _from, state) do
    {:reply, {:ok, Map.take(state, fields)}, state}
  end

  # log that a person has entered a room
  def handle_call({:walk_into, new_room}, _from, %PersonWorker{} = state) when is_atom(:new_room) do
    movement = lookup_pids_for_move(state, new_room)
    new_state = HouseParty.PersonMove.walk_into(state, movement)
    {:reply, :ok, new_state}
  end

  # begin wanderlust
  def handle_call({:wanderlust}, _from, %PersonWorker{} = state) do
    wanderlust_schedule_next(state)
    {:reply, :ok, state}
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
  def handle_cast({:swarm, :end_handoff, state}, _init_state) do
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


  # start wandering between rooms
  def handle_cast({:wander}, _from, %PersonWorker{} = state) do
    new_state = wander(state)
    wanderlust_schedule_next(new_state)
    {:noreply, new_state}
  end
  def handle_info({:wander}, %PersonWorker{} = state) do
    new_state = wander(state)
    wanderlust_schedule_next(new_state)
    {:noreply, new_state}
  end



  # this message is sent when this process should die
  # because it is being moved, use this as an opportunity
  # to clean up
  def handle_info({:swarm, :die}, %PersonWorker{name: name} = state) do
    # should do cleanup...?  maybe swarm will auto-move?
    Logger.debug(fn() -> "Person: #{name} got :swarm :die" end)
    {:stop, :shutdown, state}
  end
  def handle_info(:timeout, %PersonWorker{name: name} = state) do
    Logger.debug(fn() -> "Person: #{name} got :timeout" end)
    {:stop, :shutdown, state}
  end

  # ====================
  # == Private Internal Functions,
  # == exposed via handle_call/handle_cast via GenServer
  # ====================

  @doc """
  wanderlust is a desire to wander, until we are done, and leave the party.

  this function does not update state at all, but only schedules future work.
  """
  def wanderlust_schedule_next(%PersonWorker{current_room: :left_party} = person) do
    # Logger.info(fn() -> "wanderlust_schedule_next skipped, #{person.name} has left the party" end)
    :ok
  end
  def wanderlust_schedule_next(%PersonWorker{current_room: nil, wander_delay_ms: wander_delay_ms} = _person) do
    # 10x the normal delay, with up to 1x random added
    add = :rand.uniform(wander_delay_ms)
    delay = ((wander_delay_ms * 10) + add)
    Process.send_after(self(), {:wander}, delay)
  end
  def wanderlust_schedule_next(%PersonWorker{wander_delay_ms: wander_delay_ms} = _person) do
    # +/- up to 10% randomized
    subtract = :rand.uniform(Kernel.trunc(wander_delay_ms / 20))
    add = :rand.uniform(Kernel.trunc(wander_delay_ms / 10))
    delay = ((wander_delay_ms - subtract) + add)
    Process.send_after(self(), {:wander}, delay)
  end


  @doc """
  pick a new room to wander into, or decide it's time to leave

  ## Examples

      iex> room_names = [:kitchen]
      iex> %HouseParty.PersonWorker{} |> HouseParty.PersonWorker.wander_pick_new_room(room_names)
      :kitchen

      iex> room_names = [:den, :kitchen]
      iex> %HouseParty.PersonWorker{current_room: :den} |> HouseParty.PersonWorker.wander_pick_new_room(room_names)
      :kitchen

      iex> room_names = [:kitchen]
      iex> %HouseParty.PersonWorker{current_room: :kitchen} |> HouseParty.PersonWorker.wander_pick_new_room(room_names)
      nil

      iex> room_names = [:den, :kitchen]
      iex> %HouseParty.PersonWorker{count: 5, max: 5} |> HouseParty.PersonWorker.wander_pick_new_room(room_names)
      :leave

  """
  def wander_pick_new_room(%PersonWorker{count: count, max: max} = _person, _room_names) when count >= max do
    :leave
  end
  def wander_pick_new_room(%PersonWorker{current_room: :left_party} = _person, _room_names) do
    :left_party
  end
  def wander_pick_new_room(%PersonWorker{current_room: nil} = _person, room_names) do
    room_names |> Enum.random()
  end
  def wander_pick_new_room(%PersonWorker{current_room: current_room} = _person, room_names) do
    room_names = room_names |> Enum.reject(fn(room) -> room == current_room end)
    if Enum.empty?(room_names) do
      nil
    else
      room_names |> Enum.random()
    end
  end

  @doc """
  wander into a new random room
  """
  def wander(%PersonWorker{current_room: :left_party} = person) do
    Logger.error(fn() -> "wander skipped, #{person.name} has left the party" end)
  end
  def wander(%PersonWorker{} = person) do
    room_names = HouseParty.get_all_rooms()
    wander(person, room_names)
  end
  def wander(%PersonWorker{} = person, room_names) when is_list(room_names) do
    new_room = wander_pick_new_room(person, room_names)
    movement = lookup_pids_for_move(person, new_room)
    HouseParty.PersonMove.walk_into(person, movement)
  end

  @doc """
  lookup PIDs from Swarm for a room movement
  """
  def lookup_pids_for_move(%PersonWorker{current_room: current_room}, new_room) when is_atom(new_room) do
    %{
      new_room: new_room,
      new_room_pid: HouseParty.get_room_pid(new_room),
      current_room: current_room,
      current_room_pid: HouseParty.get_room_pid(current_room),
    }
  end

end

defmodule HouseParty.PersonMove do
  alias HouseParty.PersonWorker
  require Logger
  @moduledoc """
  This controls movements for a person
  It does not require access to Swarm, but therefore requires all PIDs to be known ahead of time.
  It does access HouseParty.RoomWorker (via known PIDs)
  """


  @doc """
  Walk into a new room
  This is the main inteface to Move a Person into a new Room

  Updates the RoomWorker processes via HouseParty.RoomWorker API
  Does NOT update the PersonWorker process at all, but does return the full, new state of the PersonWorker

  """
  def walk_into(%PersonWorker{current_room: :left_party} = person, _new_room) do
    Logger.error(fn() -> "walk_into skipped, #{person.name} has left the party" end)
  end
  def walk_into(%PersonWorker{} = person, movement) do
    case enter_new_room(person, movement) do
      :ok ->
        case depart_current_room(person, movement) do
          :ok ->
            update_person_on_success(person, movement)
          :cannot_leave_nil ->
            Logger.error(fn() -> "Person: #{person.name} got :cannot_leave_nil trying to depart_current_room #{movement.current_room}" end)
            update_person_on_success(person, movement)
          :error ->
            Logger.error(fn() -> "Person: #{person.name} got :error trying to depart_current_room #{movement.current_room}" end)
            person
        end
      :full ->
        update_person_on_failed_too_full(person, movement)
      :error ->
        Logger.error(fn() -> "Person: #{person.name} got :error trying to enter_new_room #{movement.new_room}" end)
        person
    end
  end
  # leave the party (enter nothing, will depart, update will finish)
  defp enter_new_room(%PersonWorker{name: person_name}, %{new_room_pid: nil, new_room: :leave}) do
    # Logger.debug(fn() -> "Person: #{person_name} is leaving the party" end)
    :ok
  end
  defp enter_new_room(%PersonWorker{name: person_name}, %{new_room_pid: nil} = movement) do
    Logger.error(fn() -> "Person: #{person_name} trying to enter_new_room #{movement.new_room} has no PID" end)
    :error
  end
  defp enter_new_room(%PersonWorker{name: person_name}, %{new_room_pid: new_room_pid}) when is_pid(new_room_pid) do
    HouseParty.RoomWorker.add_person(new_room_pid, person_name)
  end
# leave the current room
  defp depart_current_room(%PersonWorker{current_room: nil}, _movement) do
    :ok
  end
  defp depart_current_room(%PersonWorker{name: person_name}, %{current_room_pid: nil} = movement) do
    Logger.error(fn() -> "Person: #{person_name} trying to depart_current_room #{movement.current_room} has no PID" end)
    :error
  end
  defp depart_current_room(%PersonWorker{name: person_name}, %{current_room_pid: current_room_pid}) when is_pid(current_room_pid) do
    HouseParty.RoomWorker.rm_person(current_room_pid, person_name)
  end

  @doc """
  log that a person has entered a room
  """
  def update_person_on_success(%PersonWorker{log: log, count: count} = person, %{new_room: :leave}) do
    person |> Map.merge(%{
      current_room: :left_party,
      log: [{DateTime.utc_now, :leave, :leave} | log],
    })
  end
  def update_person_on_success(%PersonWorker{log: log, count: count} = person, %{new_room: new_room}) do
    person |> Map.merge(%{
      current_room: new_room,
      count: count + 1,
      log: [{DateTime.utc_now, new_room, :entered} | log],
    })
  end

  @doc """
  log that a person has tried to log_entry a full room
  """
  def update_person_on_failed_too_full(%PersonWorker{log: log, count: count} = person, %{new_room: new_room}) do
    person |> Map.merge(%{
      count: count + 1,
      log: [{DateTime.utc_now, new_room, :was_full} | log],
    })
  end
end
