defmodule Brook.Driver do
  @type serialized_event :: term()

  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback send_event(Brook.event_type(), serialized_event()) :: :ok | {:error, Brook.reason()}
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

  def send_event(type, event) do
    GenServer.cast({:via, Registry, {Brook.Registry, Brook.Server}}, {:process, event})

    :ok
  end
end
