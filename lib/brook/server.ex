defmodule Brook.Server do
  use GenServer
  require Logger

  def get(collection, key) do
    GenServer.call(via(), {:get, collection, key})
  end

  def get_all(collection) do
    GenServer.call(via(), {:get_all, collection})
  end

  def get_events(collection, key) do
    GenServer.call(via(), {:get_events, collection, key})
  end

  def start_link(%Brook.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: via())
  end

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

  def handle_call({:process, %Brook.Event{} = event}, _from, state) do
    process(event, state)
    {:reply, :ok, state}
  end

  def handle_call({:send, type, author, event}, _from, state) do
    :ok = apply(state.driver.module, :send_event, [type, author, event])
    {:reply, :ok, state}
  end

  def handle_cast({:process, %Brook.Event{} = event}, state) do
    process(event, state)
    {:noreply, state}
  end

  defp process(%{forwarded: false} = event, state) do
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

  defp process(%{forwarded: true} = event, state) do
    Enum.each(state.event_handlers, fn handler ->
      apply(handler, :handle_event, [event])
    end)
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
