defmodule Gossip.Socket.Games do
  @moduledoc """
  "games" flag functions
  """

  require Logger

  alias Gossip.Games

  @doc false
  def games_module(state), do: state.modules.games

  @doc false
  def handle_cast({:status}, state) do
    status(state)
  end

  def handle_cast({:status, remote_ref, game_name}, state) do
    status(state, remote_ref, game_name)
  end

  @doc false
  def handle_receive(state, message = %{"event" => "games/connect"}) do
    :telemetry.execute([:gossip, :events, :games, :connect], %{count: 1}, %{ref: message["ref"]})
    process_connect(state, message)
  end

  def handle_receive(state, message = %{"event" => "games/disconnect"}) do
    :telemetry.execute([:gossip, :events, :games, :disconnect], %{count: 1}, %{ref: message["ref"]})
    process_disconnect(state, message)
  end

  def handle_receive(state, message = %{"event" => "games/status"}) do
    :telemetry.execute([:gossip, :events, :games, :status, :response], %{count: 1}, %{ref: message["ref"]})
    process_status(state, message)
  end

  @doc """
  Process a "games/connect" event from the server
  """
  def process_connect(state, %{"payload" => payload}) do
    Logger.debug("Game connecting", type: :gossip)
    name = Map.get(payload, "game")
    games_module(state).game_connect(name)
    {:ok, state}
  end

  @doc """
  Process a "games/disconnect" event from the server
  """
  def process_disconnect(state, %{"payload" => payload}) do
    Logger.debug("Game disconnecting", type: :gossip)
    name = Map.get(payload, "game")
    games_module(state).game_disconnect(name)
    {:ok, state}
  end

  @doc """
  Process a "games/status" event from the server

  If no payload is found, this was requested from a single game update
  and should have a ref, pass along to the `Games` module where it's waiting
  for the response.
  """
  def process_status(state, message = %{"payload" => payload}) do
    Logger.debug("Received games/status", type: :gossip)
    Games.Internal.response(message)
    games_module(state).game_update(payload)
    {:ok, state}
  end

  def process_status(state, message) do
    Logger.debug("Received games/status", type: :gossip)
    Games.Internal.response(message)
    {:ok, state}
  end

  @doc """
  Generate a "games/status" event
  """
  def status(state) do
    message = %{
      "event" => "games/status",
      "ref" => UUID.uuid4()
    }

    {:reply, message, state}
  end

  @doc """
  Generate a "games/status" event for a specific game request

  remote_ref is being tracked in the `Games` process
  """
  def status(state, remote_ref, game_name) do
    message = %{
      "event" => "games/status",
      "ref" => remote_ref,
      "payload" => %{
        "game" => game_name,
      }
    }

    {:reply, message, state}
  end
end
