defmodule Brook.Driver.Default do
  use GenServer
  @behaviour Brook.Driver

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    {:ok, []}
  end

  def ack(_ack_ref, _ack_data) do
    :ok
  end

  def send_event(_type, _data) do
    :ok
  end
end
