defmodule Brook.Storage.Ets do
  use GenServer
  require Logger

  @table :brook_test_value

  def persist(%Brook.Event{} = event, collection, key, value) do
    GenServer.call(__MODULE__, {:persist, event, collection, key, value})
  end

  def delete(collection, key) do
    GenServer.call(__MODULE__, {:delete, collection, key})
  end

  def get(collection, key) do
    GenServer.call(__MODULE__, {:get, collection, key})
  end

  def get_events(collection, key) do
    GenServer.call(__MODULE__, {:get_events, collection, key})
  end

  def get_all(collection) do
    GenServer.call(__MODULE__, {:get_all, collection})
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    :ets.new(@table, [:named_table, :set, :protected])

    {:ok, []}
  end

  def handle_call({:persist, event, collection, key, value}, _from, state) do
    events = get_existing_events({collection, key})
    :ets.insert(@table, {{collection, key}, value, events ++ [event]})

    {:reply, :ok, state}
  end

  def handle_call({:delete, collection, key}, _from, state) do
    :ets.delete(@table, {collection, key})
    {:reply, :ok, state}
  end

  def handle_call({:get, collection, key}, _from, state) do
    case :ets.lookup(@table, {collection, key}) do
      [{_key, value, _events}] -> value
      _ -> nil
    end
    |> reply(state)
  end

  def handle_call({:get_events, collection, key}, _from, state) do
    {:reply, get_existing_events({collection, key}), state}
  end

  def handle_call({:get_all, collection}, _from, state) do
    :ets.match_object(@table, {{collection, :_}, :_, :_})
    |> Enum.map(fn {{_collection, key}, value, _events} ->
      {key, value}
    end)
    |> Enum.into(%{})
    |> reply(state)
  end

  defp get_existing_events(key) do
    case :ets.lookup(@table, key) do
      [] -> []
      [{^key, _value, events}] -> events
    end
  end

  defp reply(value, state), do: {:reply, value, state}
end
