defmodule HouseParty.Router do
  use Plug.Router
  use Plug.Debugger
  require Logger
  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)

  get "/hello" do
      send_resp(conn, 200, "world")
  end
  get "/nodes" do
      body = "self: #{inspect(:erlang.node())}\nnodes: #{inspect(:erlang.nodes())}"
      send_resp(conn, 200, body)
  end

  get "/scenario/slow" do
    HouseParty.Scenario.slow_nostatworker
    body = tldr()
    send_resp(conn, 200, body)
  end

  get "/scenario/big" do
    HouseParty.Scenario.big_nostatworker
    body = tldr()
    send_resp(conn, 200, body)
  end

  get "/stats/tldr" do
    body = tldr()
    send_resp(conn, 200, body)
  end

  # "Default" route that will get called when no other route is matched
  match _ do
    send_resp(conn, 404, "not found")
  end

  defp tldr() do
    """
    self: #{inspect(:erlang.node())}\nnodes: #{inspect(:erlang.nodes())}

    #{inspect(HouseParty.Stats.tldr())}
    """
  end

end
