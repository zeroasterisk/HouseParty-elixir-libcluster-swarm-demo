defmodule HouseParty.PersonWorker do
  use GenServer
  alias HouseParty.PersonWorker
  require Logger
  @moduledoc """
  This is the worker process for a Person, in this case,
  It is responsible for a single person in our house.
  It maintains a log for what rooms a person has entered.
  """

  defstruct [
    name: nil, # atom
    personality: :introvert,
    log: [], # [{<time>, <room>}, ...]
  ]

  # helpers to convert into atom
  defp to_atom(str) when is_atom(str), do: str
  defp to_atom(str) when is_bitstring(str), do: String.to_atom(str)


  @doc """
  Easy API to start a person worker
  """
  def start_link(name) when is_bitstring(name) or is_atom(name), do: start_link(%PersonWorker{name: name})
  def start_link(%PersonWorker{name: name} = state) when is_bitstring(name) do
    state |> Map.put(:name, String.to_atom(name)) |> start_link()
  end
  def start_link(%PersonWorker{name: name} = state) do
    GenServer.start_link(__MODULE__, state, [timeout: 10_000])
  end
  def start_link(%{} = state), do: %PersonWorker{} |> Map.merge(state) |> start_link()

  @doc """
  Stop
  """
  def stop(pid, reason \\ :normal), do: GenServer.stop(pid, reason)

  @doc """
  Dump details about the room
  """
  def dump(pid), do: GenServer.call(pid, {:dump})

  @doc """
  Log entering a room
  """
  def enter(nil), do: :ok
  def enter(pid, room), do: GenServer.call(pid, {:enter, room})


  # initialize the GenServer to maintain the state of the application
  def init(%PersonWorker{} = state) do
    {:ok, state}
  end

  # dump the current state of this person
  def handle_call({:dump}, _from, state) do
    out = state
    {:reply, {:ok, out}, state}
  end

  # log that a person has entered a room
  def handle_call({:enter, room}, _from, %PersonWorker{log: log} = state) do
    state = state |> Map.put(:log, [{DateTime.utc_now, room} | log])
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
  def handle_info({:swarm, :die}, %PersonWorker{name: name} = state) do
    # should do cleanup...?  maybe swarm will auto-move?
    Logger.debug(fn() -> "Person: #{name} got :swarm :die" end)
    {:stop, :shutdown, state}
  end
  def handle_info(:timeout, %PersonWorker{name: name} = state) do
    Logger.debug(fn() -> "Person: #{name} got :timeout" end)
    {:stop, :shutdown, state}
  end

end
