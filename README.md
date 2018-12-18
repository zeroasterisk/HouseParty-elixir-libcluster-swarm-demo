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

* Instead we will create any number of **rooms**, and **people** will walk into rooms.
* Each room and each person are independent
  [OTP processes](https://elixir-lang.org/getting-started/mix-otp/genserver.html).
* Our application will be running on multiple server nodes, managed by
  [kubernetes cluster](https://kubernetes.io)
* Our application nodes will be connected into an Erlang Cluster by
  [libcluster](https://github.com/bitwalker/libcluster) (self-healing)
* Our processes will be started on any node, and messages will be sent to the *correct* node &amp; process, by
  [swarm](https://github.com/bitwalker/swarm)
* Our processes will be migrated in case of node-shutdown, and state transferred, also by swarm.

Just to be clear, there is no database nor cache - all state lives in GenServers (RAM).

These processes live on several different physical machines, and automatically migrate between them without loosing state.

This has been run with 500_000 running processes across 3 nodes / physical machines, and could easily go higher.

**TODO verify above claims, provide metrics**

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

```elixir
iex> HouseParty.add_rooms([:kitchen, :living_room, :bathroom])
iex> HouseParty.walk_into(:kitchen, 1..99 |> Enum.map(fn(i) -> "peep_#{i}" |> String.to_atom() end))
{:error, :destination_full}
iex> HouseParty.dump()
%{
  bathroom: [],
  kitchen: [:peep_1, :peep_2, :peep_3, :peep_4, :peep_5, :peep_6, :peep_7, :peep_8, :peep_9, :peep_10],
  living_room: [],
}
iex> HouseParty.walk_into(:kitchen, :kid)
iex> HouseParty.walk_into(:den, :kid)
iex> HouseParty.walk_into(:bathroom, :kid)
iex> HouseParty.walk_into(:den, :kid)
iex> HouseParty.get_person_room_log(:kid) |> Enum.map(fn({_dt, room}) -> room end)
[
  {#DateTime<2018-12-18 05:34:34.928962Z>, :den},
  {#DateTime<2018-12-18 05:34:34.928467Z>, :bathroom},
  {#DateTime<2018-12-18 05:34:34.927777Z>, :den},
  {#DateTime<2018-12-18 05:34:34.927067Z>, :kitchen}
]
```

* All rooms and people are GenServer Processes
 * Room processes maintain a list of people in the room
 * Person processes maintain a log of rooms entered

## Basics of Swarm

We start all of our Room and Person worker *Processes* with Swarm:

```elixir
{:ok, den_room_pid} = Swarm.register_name(:room_den, HouseParty.RoomWorker, :start_link, [:den])
{:ok, kid_person_pid} = Swarm.register_name(:person_kid, HouseParty.PersonWorker, :start_link, [:kid])
```

We also create groups of pids, allowing Swarm keep track of *types of processes*:

```elixir
:ok = Swarm.join(:house_party_rooms, den_room_pid)
:ok = Swarm.join(:house_party_people, kid_person_pid)
```

Swarm can start the process on any of our servers/nodes in the cluster.

The Swarm registry keeps track of where a process is running. And the groups allow for process grouping.

```elixir
assert Swarm.registered() == [room_den: den_room_pid, person_kid: kid_person_pid]
assert Swarm.members(:house_party_rooms) == [den_room_pid]
assert Swarm.members(:house_party_people) == [kid_person_pid]
```

Given those two sets of information, we can *find* a process, and send it messages.

Swarm also gives us a convenient way to trigger a `GenServer.call()` on every process in a specific group.

In `HouseParty.dump()` we use use `Swarm.multi_call()` to send a message to all of our nodes/processes in parallel and aggregate their results.

This is easier and more efficient than selecting all of their names/pids and sending each a message and aggregating in my code.

```
Swarm.multi_call(:house_party_rooms, {:dump})
[
  ok: {:kitchen, [:kid, :play]},
  ok: {:living_room, [:bilal]},
  ok: {:den, []},
]
```

Swarm also comes with process migration, and lifecycle management.
This allows us to move a process from one server to another.

**TODO build out an example**

## Basics of our Cluster


But state must migrate when nodes add/exit the cluster.  That's the responsibility of `libcluster` and `swarm`.

TODO build k8 cluster
TODO libcluster config

