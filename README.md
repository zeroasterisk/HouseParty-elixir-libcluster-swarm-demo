# Roomy

A simple example of OTP process state, and
[kubernetes](https://kubernetes.io)
(or other) cluster managed by
[libcluster](https://github.com/bitwalker/libcluster)
and
[swarm](https://github.com/bitwalker/swarm).

## Basics of our GenServer

OTP FTW!

In this case, we will use Swarm Supervisors to start processes to manage rooms, one worker process for each room.

```elixir
{:ok, pid} = Roomy.add_room(:bathroom_1)
{:ok, pid} = Roomy.add_room(:living_room)
{:ok, [{pid, :bathroom_1}, {pid, :living_room}]} = Roomy.list_rooms()
```

And we can have people *walk into* rooms.

```elixir
{:ok, pid} = Roomy.walk_into(:bathroom_1, :alan)
{:ok, pid} = Roomy.walk_into(:living_room, :james)
{:ok, pid} = Roomy.walk_into(:living_room, :alan)
{:ok, [:alan, :james]} = Roomy.who_is_in(:living_room)
{:ok, []} = Roomy.who_is_in(:bathroom_1)
{:ok, %{bathroom_1: [], living_room: [:alan, :james]}} = Roomy.house_map()
:TODO = Roomy.print_house()
```

Assumptions:
* All rooms and people are represented by simple atoms.
* All rooms and people are unique and idempotent (can only exist once).
* People can only be in one room at a time, walking into a different room removes them from the previous room.

And we can assign people to rooms based on various criteria.

```elixir
{:ok, pid} = Roomy.assign([:poppy, :anita, :becky], :introvert)      # to least populated
{:ok, pid} = Roomy.assign([:alan, :oliver, :james], :extrovert)      # to most populated
:TODO = Roomy.print_house()
```

## Basics of our Cluster

There is no database in this example.  All state lives in GenServers.

But state must migrate when nodes add/exit the cluster.  That's the responsibility of `libcluster` and `swarm`.

TODO build k8 cluster
TODO libcluster config
