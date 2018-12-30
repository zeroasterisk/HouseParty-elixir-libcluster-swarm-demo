# If you want to test the cluster locally, you can do it with 3 different terminals
# PORT=4001 iex --name a@127.0.0.1 --cookie test -S mix
# PORT=4002 iex --name b@127.0.0.1 --cookie test -S mix
# PORT=4003 iex --name c@127.0.0.1 --cookie test -S mix

config :libcluster,
  topologies: [
    iexlocal: [
      # The selected clustering strategy. Required.
      strategy: Cluster.Strategy.Epmd,
      # Configuration for the provided strategy. Optional.
      config: [hosts: [:"a@127.0.0.1", :"b@127.0.0.1", :"c@127.0.0.1"]],
    ]
  ]
