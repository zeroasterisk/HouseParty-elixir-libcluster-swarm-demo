defmodule Roomy do
  @moduledoc """
  Documentation for Roomy.
  """

  @doc """
  Add rooms

  ## Examples

      iex> Roomy.add_rooms()
      :ok

      iex> Roomy.add_rooms([:kitchen, :living_room])
      :ok

  """
  def add_rooms(), do: :ok
  def add_rooms([]), do: :ok
  def add_rooms([room | rest]) when is_bitstring(room), do: add_rooms([String.to_atom(room) | rest])
  def add_rooms([room | rest]) when is_atom(room) do
    # TODO switch to libswarm start/registry
    #      needed for the all_rooms in rm_person
    case Roomy.RoomWorker.start_link(room) do
      {:ok, _pid} -> add_rooms(rest)
      {:error, reason} -> {:error, reason}
      :error -> {:error, "Unable to add room #{room}"}
    end
  end
  def add_rooms(room) when is_bitstring(room) or is_atom(room), do: add_rooms([room])
  def add_rooms(_), do: {:error, "Invalid room argument"}

  @doc """
  Walk into a room, add a person to a room

  ## Examples

      iex> Roomy.add_rooms([:kitchen, :living_room])
      iex> Roomy.walk_into(:living_room, :james)
      :ok

  """
  def walk_into(room, person) do
    case leave(person) do
      :ok ->
        case Roomy.RoomWorker.add_person(room, person) do
          :ok -> :ok
          :error -> {:error, "Unable to enter room #{room}"}
        end
      :error -> {:error, "Unable to enter room #{room}, could not leave first"}
    end
  end

  @doc """
  Remove a person from all rooms

  Drop the mix, I'm out!

  ## Examples

      iex> Roomy.add_rooms([:kitchen, :living_room])
      iex> Roomy.walk_into(:living_room, :james)
      iex> Roomy.leave(:james)
      :ok

  """
  def leave(person) do
    # TODO know all rooms to walk out, and walk out of them
    all_rooms = [:kitchen, :living_room]
    Roomy.RoomWorker.rm_person(all_rooms, person)
  end

  @doc """
  Walk into a room, add a person to a room

  ## Examples

      iex> Roomy.add_rooms([:kitchen, :living_room])
      iex> Roomy.walk_into(:living_room, :james)
      iex> Roomy.dump([:living_room])
      %{living_room: [:james]}

  """
  def dump([], acc), do: acc
  def dump([room | rest], acc) do
    people = case Roomy.RoomWorker.who_is_in(room) do
      {:ok, people} -> people
      {:error, reason} -> "ERROR: Unable to list room #{room}: #{reason}"
      :error -> "ERROR: Unable to enter room #{room} (unknown reason)"
    end
    dump(rest, Map.put(acc, room, people))
  end
  def dump(room, acc) when is_bitstring(room) or is_atom(room), do: dump([room], acc)
  def dump(room), do: dump(room, %{})
end
