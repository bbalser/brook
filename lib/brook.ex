defmodule Brook do
  @moduledoc ~S"""
  Brook provides an event stream client interface for distributed applications
  to communicate indirectly and asynchronously. Brook sends and receives messages
  with the event stream (typically a message queue service) via a driver module
  and persists an application-specific view of the event stream via a storage module
  (defaulting to ETS).

  ## Sample Configuration

  Brook is configured within the application environment by defining
  a keyword list with three primary keys: driver, handler, and storage.

    config :my_app, :brook,
      driver: [
        module: Brook.Driver.Json,
        init_arg: []
      ],
      handler: [MyApp.Event.Handler],
      storage: [
        modules: Brook.Storage.Ets,
        init_arg: []
      ]

  ### Driver
  The Brook driver implements a behaviour that sends messages to the event stream.
  Events are Brook structs that contain an event type, an author (or source), a
  creation timestamp, the event data, and an ack reference and ack data (following
  the lead of the [`broadway`](https://github.com/plataformatec/broadway) library.)

  The default driver sends the event message to the Brook server via `Genserver.cast`

  Additional drivers provided at this time are a json-encoding version of the default
  driver and a Kafka driver using the [`elsa`](https://github.com/bbalser/elsa) library.

  ### Handler
  The Brook handler implements a behaviour that provides a `handle_event/1` function.
  Handlers receive a Brook event and take appropriate action according to the implementing
  application's business logic.

  Applications implement as many function heads for the event handler as necessary and return
  one of four tuples depending on how the storage module should treat the event with
  respect to persistence. Events can:
  * create a record in the view state via the `{:create, collection, key, value}` return
  * update an existing record via the `{:merge, collection, key, value}` return
  * delete a record via the `{:delete, collection, key}` return
  * discard the record and do not effect the persistent view via the `:discard` return

  ### Storage
  The Brook storage module implements yet another behaviour that persists event data to
  an application view state specific to the application importing the Brook library, allowing
  the application to only store information received from the event stream that is relevant to
  its own domain and retrieve it when necessary.

  Storage modules implement basic CRUD operations that correlate to the return values of
  the event handler module.

  The default module uses ETS for fast, local, in-memory storage and retrieval (great for
  testing purposes!) with an additional Redis-based module as well.
  """
  @typedoc "The catagory of event to contextualize the data of an event message"
  @type event_type :: String.t()

  @typedoc "The data component of an event message"
  @type event :: term()

  @typedoc "The source application generating an event message"
  @type author :: String.Chars.t()

  @typedoc "The grouping of events by catagory for persisted view storage"
  @type view_collection :: String.Chars.t()

  @typedoc "The index by which events are stored in a view state collection"
  @type view_key :: String.Chars.t()

  @typedoc "The event data stored within a view state collection, indexed by key"
  @type view_value :: term()

  @typedoc "The potential negative return value of a view state query."
  @type reason :: term()

  @typedoc "The name of this instance of Brook"
  @type instance :: atom()

  defmodule Uninitialized do
    @moduledoc """
    An exception that is raised when calls are made to retrieve values
    from the view state, but Brook is Uninitialized.
    """
    defexception [:message]
  end

  defmodule InvalidInstance do
    @moduledoc """
    An exception that is raised when an instance of brook cannot be found.
    """
    defexception [:message]
  end

  defmodule InvalidEvent do
    @moduledoc """
    An exception that is raised when no valid event can be found.
    """
    defexception [:message]
  end

  @doc """
  Starts a Brook process linked to the current process.
  """
  defdelegate start_link(opts), to: Brook.Supervisor

  @doc """
  Provides a Brook Supervisor child spec for defining a custom Brook supervisor.
  """
  defdelegate child_spec(args), to: Brook.Supervisor

  @doc """
  Return an item from the Brook view state for the implementing application wrapped in an
  `:ok` tuple or else an `:error` tuple with a reason.
  """
  @spec get(instance(), view_collection(), view_key()) :: {:ok, view_value()} | {:error, reason()}
  defdelegate get(instance, collection, key), to: Brook.ViewState

  @doc """
  Returns the value stored under the given key and collection from the
  Brook view state or else raises an exception.
  """
  @spec get!(instance(), view_collection(), view_key()) :: view_value()
  def get!(instance, collection, key) do
    case get(instance, collection, key) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Returns a list of Brook events that produced the value stored under the given key
  within a collection from the Brook view state, wrapped in an `:ok` tuple or else
  an `:error` tuple with reason.
  """
  @spec get_events(instance(), view_collection(), view_key()) :: {:ok, list(Brook.Event.t())} | {:error, reason()}
  def get_events(instance, collection, key) do
    storage = Brook.Config.storage(instance)
    apply(storage.module, :get_events, [instance, collection, key])
  end

  @doc """
  Returns a list of Brook events matching the provided type that produced the value stored under the given key
  within a collection from the Brook view state, wrapped in an `:ok` tuple or else
  an `:error` tuple with reason.
  """
  @spec get_events(instance(), view_collection(), view_key(), event_type()) ::
          {:ok, list(Brook.Event.t())} | {:error, reason()}
  def get_events(instance, collection, key, type) do
    storage = Brook.Config.storage(instance)
    apply(storage.module, :get_events, [instance, collection, key, type])
  end

  @doc """
  Returns a list of Brook events that produced the value stored under the given key
  within a collection from the Brook view state or else raises an exception.
  """
  @spec get_events!(instance(), view_collection(), view_key()) :: list(Brook.Event.t())
  def get_events!(instance, collection, key) do
    case get_events(instance, collection, key) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Returns a list of Brook events matching the provided type that produced the value stored under the given key
  within a collection from the Brook view state or else raises an exception.
  """
  @spec get_events!(instance(), view_collection(), view_key(), event_type()) :: list(Brook.Event.t())
  def get_events!(instance, collection, key, type) do
    case get_events(instance, collection, key, type) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Return all values saved to the Brook view state for a given collection, wrapped in an `:ok` tuple or
  else an `:error` tuple with reason. Values are returned as a map where the keys are the keys used to
  index the saved values and the values are anything saved under a given key based on processing events.
  """
  @spec get_all(instance(), view_collection()) :: {:ok, %{required(view_key()) => view_value()}} | {:error, reason()}
  defdelegate get_all(instance, collection), to: Brook.ViewState

  @doc """
  Return all values saved to the Brook view state for a given collection or else raises an exception.
  Values are returned as a map where the keys are the keys used to index the saved values and the values
  are anything saved under a given key.
  """
  @spec get_all!(instance, view_collection()) :: %{required(view_key()) => view_value()}
  def get_all!(instance, collection) do
    case get_all(instance, collection) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @doc """
  Returns a list of all values saved to a given collection of the Brook view state, indepentent of
  the key used to index them. Results is wrapped in an `:ok` tuple or else an `:error` tuple with
  reason is returned.
  """
  @spec get_all_values(instance(), view_collection()) :: {:ok, [view_value()]} | {:error, reason()}
  def get_all_values(instance, collection) do
    case get_all(instance, collection) do
      {:ok, map} -> {:ok, Map.values(map)}
      error -> error
    end
  end

  @doc """
  Returns a list of all values saved to a given collection of the Brook view state, independent of
  the key used to index them, or else raises an exception.
  """
  @spec get_all_values!(instance, view_collection()) :: [view_value()]
  def get_all_values!(instance, collection) do
    case get_all_values(instance, collection) do
      {:ok, values} -> values
      {:error, reason} -> raise reason
    end
  end

  @spec serialize(term) :: {:ok, String.t()} | {:error, term}
  def serialize(data) do
    case Application.get_env(:brook, :serializer, :brook) do
      :brook ->
        Brook.Serializer.serialize(data)

      s when s in [:json_serde, :json_serde_bc] ->
        JsonSerde.serialize(data)
    end
  end

  @spec deserialize(String.t()) :: {:ok, term} | {:error, term}
  def deserialize(string) do
    case Application.get_env(:brook, :serializer, :brook) do
      :brook ->
        Brook.Deserializer.deserialize(string)

      :json_serde ->
        JsonSerde.deserialize(string)

      :json_serde_bc ->
        case String.contains?(string, "__brook_struct__") do
          true -> Brook.Deserializer.deserialize(string)
          false -> JsonSerde.deserialize(string)
        end
    end
  end
end
