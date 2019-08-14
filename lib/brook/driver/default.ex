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

  def send_event(type, author, data) do
    event = %Brook.Event{
      type: type,
      author: author,
      create_ts: DateTime.utc_now() |> DateTime.to_unix(),
      data: data,
      ack_ref: :ack_ref,
      ack_data: :ack_data
    }

    GenServer.cast({:via, Registry, {Brook.Registry, Brook.Server}}, {:process, event})

    :ok
  end
end
