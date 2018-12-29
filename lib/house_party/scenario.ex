defmodule HouseParty.Scenario do
  require Logger
  @moduledoc """
  This is a super-simple interface to build out various test scenarios
  """

  def intro() do
    HouseParty.StatWorker.start_link()
    intro_nostatworker
  end
  def intro_nostatworker() do
    HouseParty.Invites.setup_party(:small, :fast)
  end
  def slow() do
    HouseParty.StatWorker.start_link()
    slow_nostatworker()
  end
  def slow_nostatworker() do
    HouseParty.Invites.setup_party(:small, :slow)
  end
  def big() do
    HouseParty.StatWorker.start_link()
    big_nostatworker()
  end
  def big_nostatworker() do
    HouseParty.Invites.setup_party(:big, :fast)
  end
  def giant() do
    HouseParty.StatWorker.start_link()
    giant_nostatworker
  end
  def giant_nostatworker() do
    HouseParty.Invites.setup_party(:giant, :fast)
  end
end
