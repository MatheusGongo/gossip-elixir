defmodule Gossip do
  @moduledoc """
  Gossip client

  https://github.com/oestrich/gossip
  """

  @type channel :: String.t()

  def client_id(), do: Application.get_env(:gossip, :client_id)

  def configured?(), do: client_id() != nil

  def start_socket(), do: Gossip.Supervisor.start_socket()

  @doc """
  Send a message to the Gossip network
  """
  @spec broadcast(Gossip.Client.channel_name(), Gossip.Message.send()) :: :ok
  def broadcast(channel, message) do
    case Process.whereis(Gossip.Socket) do
      nil ->
        :ok

      _pid ->
        WebSockex.cast(Gossip.Socket, {:broadcast, channel, message})
    end
  end
end
