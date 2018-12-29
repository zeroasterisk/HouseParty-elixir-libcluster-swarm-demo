defmodule HouseParty.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger
  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    port = get_port(Application.get_env(:house_party, :port))
    Logger.info(fn() -> "starting with port #{port}" end)
    # topologies for the libcluster config
    topologies = Application.get_env(:libcluster, :topologies)
    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: HouseParty.Router, options: [port: port]),
      # Starts a worker by calling: HouseParty.Worker.start_link(arg)
      # {HouseParty.Worker, arg},
      {Cluster.Supervisor, [topologies, [name: HouseParty.ClusterSupervisor]]},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HouseParty.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # get the port from configuration, as INT or STRING - defaults 4001
  defp get_port(port) when is_integer(port), do: port
  defp get_port(port) when is_bitstring(port), do: port |> Integer.parse() |> get_port()
  defp get_port({port, _}), do: port
  defp get_port(_), do: 4001 # default port, easier defaulting/development
end
