defmodule Brook.Driver do
  @type ack_ref :: term()
  @type ack_data :: term()

  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback ack(ack_ref(), list(ack_data())) :: :ok

  @callback send_event(Brook.event_type(), Brook.author(), Brook.event()) :: :ok | {:error, Brook.reason()}
end

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

defmodule Brook.Driver.Json do
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
      data: data |> Jason.encode!() |> Jason.decode!(),
      ack_ref: :ack_ref,
      ack_data: :ack_data
    }

    GenServer.cast({:via, Registry, {Brook.Registry, Brook.Server}}, {:process, event})

    :ok
  end
end
