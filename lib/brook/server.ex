defmodule Brook.Server do
  @moduledoc """
  Process event messages to and from the underlying event stream
  message bus implementation. Interact with the application's
  persisted view state of the event stream with getter and setter
  functions to write and update events from the view state as well
  as delete them.
  """
  use GenServer
  require Logger

  @doc """
  Return an value, stored under a given key for a given
  collection from the view state.
  """
  @spec get(Brook.view_collection(), Brook.view_key()) :: {:ok, Brook.view_value()} | {:error, Brook.reason()}
  def get(collection, key) do
    GenServer.call(via(), {:get, collection, key})
  end

  @doc """
  Return all values stored in the view state for a given
  collection. Values are returned as a map where the keys
  are the term used to store the value to the view state
  and the values are the data produced from event processing.
  """
  @spec get_all(Brook.view_collection()) ::
          {:ok, %{required(Brook.view_key()) => Brook.view_value()}} | {:error, Brook.reason()}
  def(get_all(collection)) do
    GenServer.call(via(), {:get_all, collection})
  end

  @doc """
  Returns a list of Brook events that produced the value saved under
  the given key within a collection from the application view state.
  """
  @spec get_events(Brook.view_collection(), Brook.view_key()) :: {:ok, list(Brook.Event.t())} | {:error, Brook.reason()}
  def(get_events(collection, key)) do
    GenServer.call(via(), {:get_events, collection, key})
  end

  @doc """
  Start a Brook server and link it to the current process
  """
  @spec start_link(term()) :: {:ok, pid()}
  def start_link(%Brook.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: via())
  end

  @doc """
  Initialize a Brook server configuration.
  """
  @spec init(term()) :: {:ok, term()}
  def init(%Brook.Config{} = config) do
    config.dispatcher.init()

    {:ok, config}
  end

  def handle_call({:get, collection, key}, _from, state) do
    value = apply(state.storage.module, :get, [collection, key])
    {:reply, {:ok, value}, state}
  end

  def handle_call({:get_all, collection}, _from, state) do
    values = apply(state.storage.module, :get_all, [collection])
    {:reply, {:ok, values}, state}
  end

  def handle_call({:get_events, collection, key}, _from, state) do
    events = apply(state.storage.module, :get_events, [collection, key])
    {:reply, {:ok, events}, state}
  end

  def handle_call({:process, event}, _from, state) do
    process(event, state)
    {:reply, :ok, state}
  end

  def handle_call({:send, type, author, event}, _from, state) do
    brook_event = %Brook.Event{
      type: type,
      author: author,
      data: event
    }

    case Brook.Event.Serializer.serialize(brook_event) do
      {:ok, serialized_event} ->
        :ok = apply(state.driver.module, :send_event, [type, serialized_event])

      {:error, reason} ->
        Logger.error(
          "Unable to send event: type(#{type}), author(#{author}), event(#{inspect(event)}), error reason: #{
            inspect(reason)
          }"
        )
    end

    {:reply, :ok, state}
  end

  def handle_cast({:process, event}, state) do
    process(event, state)
    {:noreply, state}
  end

  defp process(%Brook.Event{forwarded: false} = event, state) do
    Enum.each(state.event_handlers, fn handler ->
      case apply(handler, :handle_event, [event]) do
        {:create, collection, key, value} ->
          apply(state.storage.module, :persist, [event, collection, key, value])

        {:merge, collection, key, value} ->
          merged_value = merge(collection, key, value, state)
          apply(state.storage.module, :persist, [event, collection, key, merged_value])

        {:delete, collection, key} ->
          apply(state.storage.module, :delete, [collection, key])

        :discard ->
          nil
      end
    end)

    apply(state.dispatcher, :dispatch, [event])
  end

  defp process(%Brook.Event{forwarded: true} = event, state) do
    Enum.each(state.event_handlers, fn handler ->
      apply(handler, :handle_event, [event])
    end)
  end

  defp process(event, state) do
    case Brook.Event.Deserializer.deserialize(struct(Brook.Event), event) do
      {:ok, brook_event} ->
        process(brook_event, state)

      {:error, reason} ->
        Logger.error("Unable to deserialize event: #{inspect(event)}, error reason: #{inspect(reason)}")
    end
  end

  defp merge(collection, key, %{} = value, state) do
    do_merge(collection, key, value, &Map.merge(&1, value), state)
  end

  defp merge(collection, key, value, state) when is_list(value) do
    do_merge(collection, key, value, &Keyword.merge(&1, value), state)
  end

  defp merge(collection, key, function, state) when is_function(function) do
    do_merge(collection, key, nil, function, state)
  end

  defp do_merge(collection, key, default, function, state) when is_function(function, 1) do
    case apply(state.storage.module, :get, [collection, key]) do
      nil -> default
      old_value -> function.(old_value)
    end
  end

  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
end
