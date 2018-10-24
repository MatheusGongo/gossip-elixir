defmodule Gossip.Socket do
  @moduledoc """
  The websocket connection to the Gossip network
  """

  use WebSockex

  require Logger

  alias Gossip.Monitor
  alias Gossip.Socket.Core
  alias Gossip.Socket.Implementation

  def url() do
    Application.get_env(:gossip, :url) || "wss://gossip.haus/socket"
  end

  def start_link() do
    state = %{
      authenticated: false,
      channels: [],
    }

    Logger.debug("Starting socket", type: :gossip)

    WebSockex.start_link(url(), __MODULE__, state, [name: Gossip.Socket])
  end

  def handle_connect(_conn, state) do
    Monitor.monitor()

    send(self(), {:authorize})
    {:ok, state}
  end

  def handle_frame({:text, message}, state) do
    case Implementation.receive(state, message) do
      {:ok, state} ->
        {:ok, state}

      {:reply, message, state} ->
        {:reply, {:text, message}, state}

      :stop ->
        Logger.info("Closing the Gossip websocket", type: :gossip)
        {:close, state}

      :error ->
        {:ok, state}
    end
  end

  def handle_frame(_frame, state) do
    {:ok, state}
  end

  def handle_cast({:core, message}, state) do
    Core.handle_cast(message, state)
  end

  def handle_cast({:player_sign_in, player_name}, state) do
    case Implementation.player_sign_in(state, player_name) do
      {:reply, message, state} ->
        {:reply, {:text, message}, state}

      {:ok, state} ->
        {:ok, state}
    end
  end

  def handle_cast({:player_sign_out, player_name}, state) do
    case Implementation.player_sign_out(state, player_name) do
      {:reply, message, state} ->
        {:reply, {:text, message}, state}

      {:ok, state} ->
        {:ok, state}
    end
  end

  def handle_cast(:players_status, state) do
    case Implementation.players_status(state) do
      {:reply, message, state} ->
        {:reply, {:text, message}, state}

      {:ok, state} ->
        {:ok, state}
    end
  end

  def handle_cast(:games_status, state) do
    case Implementation.games_status(state) do
      {:reply, message, state} ->
        {:reply, {:text, message}, state}

      {:ok, state} ->
        {:ok, state}
    end
  end

  def handle_cast({:send, message}, state) do
    {:reply, {:text, Poison.encode!(message)}, state}
  end

  def handle_cast(_, state) do
    {:ok, state}
  end

  def handle_info({:authorize}, state) do
    {:reply, message, state} = Core.authenticate(state)
    {:reply, {:text, Poison.encode!(message)}, state}
  end
end
