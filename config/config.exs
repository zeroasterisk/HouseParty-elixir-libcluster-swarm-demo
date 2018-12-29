# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger,
  level: :info

config :swarm,
  # node_whitelist: [~r/^myapp-[\d]@.*$/]
  distribution_strategy: Swarm.Distribution.Ring, # Swarm.Distribution.StaticQuorumRing
  debug: false

# configuration for libcluster allowing it to get config from Kubernetes
config :libcluster, :debug, true
config :libcluster,
  topologies: [
    hpgcpcluster: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :ip, # :dns,
        # these must match the Kubernetes Deployment values
        kubernetes_node_basename: "housepartyapp",
        kubernetes_selector: "app=housepartyapp",
        # how fast are we checking for changes?
        polling_interval: 10_000,
      ]
    ]
  ]

# PORT will need to be set via ENV variables for a distillary release
# you will also need to pass REPLACE_OS_VARS=true when starting the release
# more info: https://hexdocs.pm/distillery/config/runtime.html
# example:
# REPLACE_OS_VARS=true PORT=8080 _build/prod/rel/house_party/bin/house_party foreground
config :house_party, port: "${PORT}"


# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :house_party, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:house_party, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"
