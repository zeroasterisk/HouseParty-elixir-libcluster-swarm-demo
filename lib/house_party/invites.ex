defmodule HouseParty.Invites do
  alias HouseParty.PersonWorker
  alias HouseParty.RoomWorker
  require Logger
  @moduledoc """
  This is a set of convenience functions for inviting people to the house party
  """


  @movie_cast [
      :kid,
      :pop,
      :play,
      :bilal,
      :sidney,
      :sharane,
      :stab,
      :pee_wee,
      :zilla,
      :principal,
      :ladonna,
      :peanut,
      :uncle_otis,
      :sunni,
      :roughouse,
      :dj,
      :mildred,
      :groove,
      :chill,
      :herman,
      :clint,
      :benita,
      :lashay,
      :everett,
      :eze,
      :cop_1,
      :cop_2 ,
      :burglar_1,
      :burglar_2,
      :pimp,
    ]

  @doc """
  This uses the HouseParty API and some convenience tooling to setup some basic parties
  """
  def setup_party(:small, :fast) do
    template_person = %PersonWorker{max: 20, wander_delay_ms: 100}
    template_room = %RoomWorker{max: 10}
    room_names = [:kitchen, :living_room, :den, :hallway, :dining_room]
    build_party_from_templates(template_room, room_names, template_person, @movie_cast)
    Swarm.multi_call(:house_party_people, {:wanderlust})
  end
  def setup_party(:small, :slow) do
    template_person = %PersonWorker{max: 100, wander_delay_ms: 500}
    template_room = %RoomWorker{max: 5}
    room_names = [:kitchen, :living_room, :den, :hallway, :dining_room]
    build_party_from_templates(template_room, room_names, template_person, @movie_cast)
    Swarm.multi_call(:house_party_people, {:wanderlust})
  end
  def setup_party(:big, :fast) do
    template_person = %PersonWorker{max: 10, wander_delay_ms: 100}
    template_room = %RoomWorker{max: 25}
    build_party_from_templates(template_room, 50, template_person, 2_000)
    Swarm.multi_call(:house_party_people, {:wanderlust})
  end
  def setup_party(:giant, :fast) do
    template_person = %PersonWorker{max: 10, wander_delay_ms: 100}
    template_room = %RoomWorker{max: 50}
    build_party_from_templates(template_room, 100, template_person, 10_000)
    Swarm.multi_call(:house_party_people, {:wanderlust})
  end

  @doc """
  Build out custom party configurations, given a template and a list of names
  """
  def build_party_from_templates(template_room, n_rooms, template_person, n_people) when is_integer(n_rooms) and is_integer(n_people) do
    HouseParty.reset()
    Range.new(1, n_rooms)
    |> Enum.map(fn(i) -> String.to_atom("room_#{i}") end)
    |> Enum.map(fn(name) -> Map.merge(template_room, %{name: name}) end)
    |> HouseParty.add_rooms()
    Range.new(1, n_people)
    |> Enum.map(fn(i) -> String.to_atom("person_#{i}") end)
    |> Enum.map(fn(name) -> Map.merge(template_person, %{name: name}) end)
    |> HouseParty.add_people()
    :ok
  end
  def build_party_from_templates(template_room, room_names, template_person, people_names) do
    HouseParty.reset()
    room_names
    |> Enum.map(fn(name) -> Map.merge(template_room, %{name: name}) end)
    |> HouseParty.add_rooms()
    people_names
    |> Enum.map(fn(name) -> Map.merge(template_person, %{name: name}) end)
    |> HouseParty.add_people()
    :ok
  end

end
