defmodule HouseParty.StatWorker do
  use GenServer
  alias HouseParty.Stats
  require Logger
  @moduledoc """
  This will schedule regular stat emitting
  And it will handle special circumstances for ending stat monitoring
  """
  @default_config %{ttl_ms: 2_000, stat: :tldr}


  def start_link(state \\ nil) do
    GenServer.start_link(__MODULE__, state, [name: __MODULE__, timeout: :infinity])
  end
  def config(%{} = config) do
    GenServer.call(__MODULE__, {:config, config})
  end
  def clear() do
    GenServer.call(__MODULE__, {:config, @default_config})
  end

  # ====================

  def init(nil) do
    schedule_next(@default_config)
    {:ok, @default_config}
  end
  def init(%{} = state) do
    schedule_next(state)
    {:ok, state}
  end

  def handle_call({:config, config}, _from, state) do
    {:reply, :ok, Map.merge(state, config)}
  end

  def handle_info({:tick}, state) do
    if state.stat == :tldr do
      Logger.info("#{inspect(HouseParty.Stats.tldr())}")
    end
    schedule_next(state)
    {:noreply, state}
  end

  def schedule_next(%{ttl_ms: ttl_ms} = _state) when is_integer(ttl_ms) do
    Process.send_after(self(), {:tick}, ttl_ms)
  end
  def schedule_next(%{} = _state) do
    Process.send_after(self(), {:tick}, 30_000)
  end


end
