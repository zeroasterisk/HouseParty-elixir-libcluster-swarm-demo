# Roomy

A simple example of OTP process state, and
[kubernetes](https://kubernetes.io)
(or other) cluster managed by
[libcluster](https://github.com/bitwalker/libcluster)
and
[swarm](https://github.com/bitwalker/swarm).

## Basics of our GenServer

OTP FTW!

In this case, we will use *Swarm* to start processes which will manage rooms, one worker process for each room.

### The basic Roomy API


```elixir
iex> Roomy.add_room(:den)
:ok
iex> Roomy.add_room(:living_room)
:ok
iex> Roomy.get_all_rooms()
[:den, :living_room]
```

And we can have people *walk into* rooms.

```elixir
iex> Roomy.add_rooms([:kitchen, :living_room])
:ok
iex> Roomy.walk_into(:kitchen, :alan)
:ok
iex> Roomy.walk_into(:living_room, :james)
:ok
iex> Roomy.who_is_in(:living_room)
[:james]
iex> Roomy.dump()
%{kitchen: [:alan], living_room: [:james]}
```

A bit more about how people fit into rooms:
* All rooms and people are represented by simple atoms.
* All rooms and people are unique and idempotent (can only exist once).
* People can only be in one room at a time, walking into a different room removes them from the previous room.
* Trying to keep this simple, we do not have restrictions about which rooms can connect to other rooms, but we could...

```elixir
iex> Roomy.add_rooms([:kitchen, :living_room, :bedroom_king])
:ok
iex> Roomy.walk_into(:living_room, [:alan, :james, :lucy])
:ok
iex> Roomy.walk_into(:bedroom_king, [:james, :lucy, :jess])
:ok
iex> Roomy.dump([:living_room, :bedroom_king])
%{
  bedroom_king: [:james, :jess, :lucy],
  living_room: [:alan],
}
```

## Basics of Swarm

Swarm takes care of *distributing* these Rooms to any available nodes in our cluster
and maintaining a *registry* of processes, so we can easily access them by name,
no matter where the process is running.

TODO add more information about how swarm is used
TODO add more information about groups of pids

### Swarm.multi_call is a great convenience

In `Roomy.dump()` we use use `Swarm.multi_call()` to send a message to all of our nodes/processes in parallel and aggregate their results.

This is easier and more efficient than selecting all of their names/pids and sending each a message and aggregating in my code.

```
Swarm.multi_call(Roomy, {:who_is_in})
[ok: [:alan], ok: [:james], ok: []]

Swarm.multi_call(Roomy, {:dump})
[
  ok: {:kitchen, MapSet.new([:alan])},
  ok: {:living_room, MapSet.new([:james])},
  ok: {:den, MapSet.new([])},
]
```

## Basics of our Cluster

There is no database in this example.  All state lives in GenServers.

But state must migrate when nodes add/exit the cluster.  That's the responsibility of `libcluster` and `swarm`.

TODO build k8 cluster
TODO libcluster config

