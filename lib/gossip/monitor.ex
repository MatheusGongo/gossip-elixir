defmodule Gossip.Monitor do
  @moduledoc """
  A side process to monitor and restart the websocket for Gossip
  """

  use GenServer, restart: :permanent

  @boot_delay 1_000
  @restart_delay 15_000
  @sweep_delay 30_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def monitor() do
    GenServer.cast(__MODULE__, {:monitor, self()})
  end

  def restart_incoming(delay) do
    GenServer.cast(__MODULE__, {:restart_incoming, delay})
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    Process.send_after(self(), :check_socket_alive, @boot_delay)
    {:ok, %{process: nil, online: false, known_delay: nil}}
  end

  def handle_cast({:monitor, pid}, state) do
    Process.link(pid)

    state =
      state
      |> Map.put(:online, true)
      |> Map.put(:process, pid)

    {:noreply, state}
  end

  def handle_cast({:restart_incoming, delay}, state) do
    state = Map.put(state, :known_delay, :timer.seconds(delay))
    {:noreply, state}
  end

  def handle_info(:restart_socket, state) do
    Gossip.start_socket()
    {:noreply, state}
  end

  def handle_info(:check_socket_alive, state) do
    Gossip.start_socket()
    Process.send_after(self(), :check_socket_alive, @sweep_delay)
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, _reason}, state) do
    case state.process == pid do
      true ->
        state =
          state
          |> Map.put(:online, false)
          |> Map.put(:process, nil)

        delay = get_delay(state)
        Process.send_after(self(), :restart_socket, delay)

        {:noreply, state}

      false ->
        {:noreply, state}
    end
  end

  defp get_delay(state) do
    case Map.get(state, :known_delay) do
      nil ->
        @restart_delay

      delay ->
        delay
    end
  end
end
