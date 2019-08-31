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
    Brook.ViewState.init()
    config.dispatcher.init()

    {:ok, config}
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

    case Brook.Serializer.serialize(brook_event) do
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
    Process.put(:brook_current_event, event)

    Enum.each(state.event_handlers, fn handler ->
      case apply(handler, :handle_event, [event]) do
        {:create, collection, key, value} ->
          Brook.ViewState.create(collection, key, value)

        {:merge, collection, key, value} ->
          Brook.ViewState.merge(collection, key, value)

        {:delete, collection, key} ->
          Brook.ViewState.delete(collection, key)

        :discard ->
          nil

        :ok ->
          nil
      end
    end)
    Brook.ViewState.commit()

    apply(state.dispatcher, :dispatch, [event])
    Process.delete(:brook_current_event)
  end

  defp process(%Brook.Event{forwarded: true} = event, state) do
    Process.put(:brook_current_event, event)

    Enum.each(state.event_handlers, fn handler ->
      apply(handler, :handle_event, [event])
    end)

    Brook.ViewState.rollback()
    Process.delete(:brook_current_event)
  end

  defp process(event, state) do
    case Brook.Deserializer.deserialize(struct(Brook.Event), event) do
      {:ok, brook_event} ->
        process(brook_event, state)

      {:error, reason} ->
        Logger.error("Unable to deserialize event: #{inspect(event)}, error reason: #{inspect(reason)}")
    end
  end

  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
end
