defmodule Brook.Storage do
  @moduledoc """
  Defines the `Brook.Storage` behaviour that must be implemented by
  storage driver processes. Starts a process and defines a child specification
  for including the driver in Brook's supervision tree.

  Implements the CRUD functionality for persisting events to the application
  view state within the storage driver and subsequent retrieval.
  """

  @doc """
  Start the storage driver and link it to the current process.
  """
  @callback start_link([registry: Brook.registry()]) :: GenServer.on_start()

  @doc """
  Define a child specification for including the storage driver in the Brook
  supervision tree.
  """
  @callback child_spec(term()) :: Supervisor.child_spec()

  @doc """
  Save a value from a processed event to the application view state
  stored on the underlying storage system. Events are saved to a collection of
  related events under a given identifying key.

  The event is simultaneously stored under a different key to serve as a log of
  all events that produced or modified the value saved to the given key and collection.
  """
  @callback persist(Brook.registry(), Brook.Event.t(), Brook.view_collection(), Brook.view_key(), Brook.view_value()) ::
              :ok | {:error, Brook.reason()}

  @doc """
  Delete the record of a saved value from the view state within a given collection and
  identified by a given key.
  """
  @callback delete(Brook.registry(), Brook.view_collection(), Brook.view_key()) :: :ok | {:error, Brook.reason()}

  @doc """
  Return a value from the persisted view state stored within a collection and
  identified by a key.
  """
  @callback get(Brook.registry(), Brook.view_collection(), Brook.view_key()) :: {:ok, Brook.view_value()} | {:error, Brook.reason()}

  @doc """
  Return all values saved to the application view state within the storage system
  under a given collection. Events are returned as a map with the identifying keys as keys and the
  saved values as values.
  """
  @callback get_all(Brook.registry(), Brook.view_collection()) ::
              {:ok, %{required(Brook.view_key()) => Brook.view_value()}} | {:error, Brook.reason()}

  @doc """
  Return a list of events that produced a value saved to the application view state
  within the storage system under a given collection and idetifying key.
  """
  @callback get_events(Brook.registry(), Brook.view_collection(), Brook.view_key()) ::
              {:ok, list(Brook.Event.t())} | {:error, Brook.reason()}
end
