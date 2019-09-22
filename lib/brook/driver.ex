defmodule Brook.Driver do
  @moduledoc """
  Defines the behaviour clients must implement in order to send events
  to the event stream. Ensures a child specification is defined and a process
  can be started and linked to the calling process, as well as sending
  serialized events with an accompanying event type for pattern matching to handle
  different types of events from a single client event handling module.
  """

  @typedoc "Brook event message data encoded to a serialized format"
  @type serialized_event :: term()

  @doc """
  Start a Brook driver and link to the current process.
  """
  @callback start_link([instance: Brook.instance()]) :: GenServer.on_start()

  @doc """
  Return a child specification for the Brook driver for inclusion
  in an application supervision tree.
  """
  @callback child_spec(term()) :: Supervisor.child_spec()

  @doc """
  Send a Brook event to the event stream with a contextual event
  type and a data value serialized for transfer.
  """
  @callback send_event(Brook.instance(), Brook.event_type(), serialized_event()) :: :ok | {:error, Brook.reason()}
end

defmodule Brook.Driver.Default do
  @moduledoc """
  Default implmentation of the `Brook.Driver` behaviour.
  Simply casts the event to the Brook server by way of a registry lookup.
  """
  use GenServer
  @behaviour Brook.Driver

  @doc """
  Start the default Brooker driver GenServer and link it to the current process.
  """
  @impl Brook.Driver
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc """
  Initializes the default Brook driver with an empty state.
  """
  @impl GenServer
  def init(_args) do
    {:ok, []}
  end

  @doc """
  Takes event data and casts to the Brook server to process.
  """
  @impl Brook.Driver
  def send_event(instance, _type, event) do
    registry = Brook.Config.registry(instance)
    GenServer.cast({:via, Registry, {registry, Brook.Server}}, {:process, event})

    :ok
  end
end
