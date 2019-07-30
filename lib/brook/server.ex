defmodule Brook.Server do
  use GenServer
  require Logger

  alias Brook.Tracking

  def get(key) do
    GenServer.call(via(), {:get, key})
  end

  def get_events(key) do
    GenServer.call(via(), {:get_events, key})
  end

  def start_link(%Brook.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: via())
  end

  def init(%Brook.Config{} = config) do
    {:ok, config}
  end

  def handle_call({:get, key}, _from, state) do
    value = apply(state.storage.module, :get, [key])
    {:reply, value, state}
  end

  def handle_call({:get_events, key}, _from, state) do
    events = apply(state.storage.module, :get_events, [key])
    {:reply, events, state}
  end

  def handle_call({:process, %Brook.Event{} = event}, _from, state) do
    Enum.each(state.event_handlers, fn handler ->
      case apply(handler, :handle_event, [event]) do
        {:create, key, value} ->
          apply(state.storage.module, :persist, [event, key, value])

        {:merge, key, value} ->
          merged_value = merge(key, value, state)
          apply(state.storage.module, :persist, [event, key, merged_value])

        {:delete, key} ->
          apply(state.storage.module, :delete, [key])

        :discard ->
          nil
      end
    end)

    {:reply, :ok, state}
  end

  defp merge(key, %{} = value, state) do
    do_merge(key, value, &Map.merge(&1, value), state)
  end

  defp merge(key, value, state) when is_list(value) do
    do_merge(key, value, &Keyword.merge(&1, value), state)
  end

  defp merge(key, function, state) when is_function(function) do
    do_merge(key, nil, function, state)
  end

  defp do_merge(key, default, function, state) when is_function(function, 1) do
    case apply(state.storage.module, :get, [key]) do
      nil -> default
      old_value -> function.(old_value)
    end
  end

  def handle_call({:send, type, event}, _from, state) do
    :ok = apply(state.driver.module, :send_event, [type, event])
    {:reply, :ok, state}
  end

  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
end
