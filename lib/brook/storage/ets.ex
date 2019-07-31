defmodule Brook.Storage.Ets do
  use GenServer
  require Logger

  @table :brook_test_value

  def persist(%Brook.Event{} = event, key, value) do
    GenServer.call(__MODULE__, {:persist, event, key, value})
  end

  def delete(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def get_events(key) do
    GenServer.call(__MODULE__, {:get_events, key})
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    :ets.new(@table, [:named_table, :set, :protected])

    {:ok, []}
  end

  def handle_call({:persist, event, key, value}, _from, state) do
    events = get_existing_events(key)
    :ets.insert(@table, {key, value, events ++ [event]})

    {:reply, :ok, state}
  end

  def handle_call({:delete, key}, _from, state) do
    :ets.delete(@table, key)
    {:reply, :ok, state}
  end

  def handle_call({:get, key}, _from, state) do
    value =
      case :ets.lookup(@table, key) do
        [{^key, value, _events}] -> value
        _ -> nil
      end

    {:reply, value, state}
  end

  def handle_call({:get_events, key}, _from, state) do
    {:reply, get_existing_events(key), state}
  end

  defp get_existing_events(key) do
    case :ets.lookup(@table, key) do
      [] -> []
      [{^key, _value, events}] -> events
    end
  end
end
