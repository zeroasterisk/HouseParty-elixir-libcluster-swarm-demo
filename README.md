# HouseParty

A simple example of OTP process state, in a
[kubernetes cluster](https://kubernetes.io)
(or other) managed by
[libcluster](https://github.com/bitwalker/libcluster),
and process registry and management with
[swarm](https://github.com/bitwalker/swarm).


## Basics of our GenServer

[![House Party Poster](./houseparty_poster.jpg)](https://www.imdb.com/title/tt0099800/)

In the 1990 classic, [House Party](https://www.imdb.com/title/tt0099800/):

> Kid decides to go to his friend Play's house party, but neither of them can predict what's in store for them on what could be the wildest night of their lives.

Sadly, this example wont be quite so wild.

* Instead we will create any number of **rooms**, and **people** will roam into rooms.
* Each room and each person are independent
  [OTP processes](https://elixir-lang.org/getting-started/mix-otp/genserver.html).
* Our application will running on multiple server nodes, managed by
  [kubernetes cluster](https://kubernetes.io)
* Our application nodes will be connected into an Erlang Cluster by
  [libcluster](https://github.com/bitwalker/libcluster)
* Our processes will be started on any node, and messages will be sent to the *correct* node &amp; process, by
  [swarm](https://github.com/bitwalker/swarm)

### The basic HouseParty API

We add rooms and we can have people *walk into* rooms.

```elixir
iex> HouseParty.add_rooms([:den, :living_room, :kitchen])
:ok
iex> HouseParty.walk_into(:kitchen, [:kid, :bilal])
:ok
iex> HouseParty.walk_into(:living_room, [:play, :sidney, :kid])
:ok
iex> HouseParty.dump()
%{den: [], kitchen: [:bilal], living_room: [:kid, :play, :sidney]}
iex> HouseParty.who_is_in(:kitchen)
[:bilal]
iex> HouseParty.where_is(:kid)
:living_room
```

A bit more about how people fit into rooms:
* All rooms and people are represented by simple atoms.
* All rooms and people are unique and idempotent (can only exist once).
* People can only be in one room at a time, walking into a different room removes them from the previous room.
* Trying to keep this simple, we do not have restrictions about which rooms can connect to other rooms *(but we could...)*
* Rooms default to a `max` of `10` people (can be configured per room) and when a room is `:full` nobody can go into it.
* All rooms and people are GenServer Processes
 * Room processes maintain a list of people in the room
 * Person processes maintain a log of rooms entered

```elixir
iex> HouseParty.add_rooms([:kitchen, :living_room, :bedroom_king])
iex> HouseParty.walk_into(:kitchen, 1..99 |> Enum.map(fn(i) -> "peep_#{i}" |> String.to_atom() end))
{:error, :destination_full}
iex> HouseParty.dump()
%{
  bedroom_king: [],
  kitchen: [:peep_1, :peep_2, :peep_3, :peep_4, :peep_5, :peep_6, :peep_7, :peep_8, :peep_9, :peep_10],
  living_room: [],
}
```

## Basics of Swarm

Swarm takes care of *distributing* these Rooms to any available nodes in our cluster
and maintaining a *registry* of processes, so we can easily access them by name,
no matter where the process is running.

TODO add more information about how swarm is used
TODO add more information about groups of pids

### Swarm.multi_call is a great convenience

In `HouseParty.dump()` we use use `Swarm.multi_call()` to send a message to all of our nodes/processes in parallel and aggregate their results.

This is easier and more efficient than selecting all of their names/pids and sending each a message and aggregating in my code.

```
Swarm.multi_call(HouseParty, {:who_is_in})
[ok: [:alan], ok: [:james], ok: []]

Swarm.multi_call(HouseParty, {:dump})
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

