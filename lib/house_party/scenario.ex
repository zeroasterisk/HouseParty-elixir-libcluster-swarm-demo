defmodule HouseParty.Scenario do
  require Logger
  @moduledoc """
  This is a super-simple interface to build out various test scenarios
  """

  def stats_start() do
    HouseParty.StatWorker.start_link()
  end
  def stats_start() do
    GenServer.stop(HouseParty.StatWorker)
  end
  def intro() do
    HouseParty.Invites.setup_party(:small, :fast)
  end
  def slow() do
    HouseParty.Invites.setup_party(:small, :slow)
  end
  def big() do
    HouseParty.Invites.setup_party(:big, :fast)
  end
  def giant() do
    # warning - this is real bad news
    HouseParty.Invites.setup_party(:giant, :fast)
  end
end
