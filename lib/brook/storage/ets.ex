defmodule Brook.Storage.Ets do
  @moduledoc """
  Implements the `Brook.Storage` behaviour for ETS,
  saving the application view state to the in-memory Erlang
  key/value datastore.

  As ETS is in-memory, this implementation is intended
  for testing purposes and not recommended for production
  persistence of application data.
  """
  use GenServer
  require Logger
  import Brook.Config, only: [registry: 1]
  @behaviour Brook.Storage

  @impl Brook.Storage
  def persist(instance, %Brook.Event{} = event, collection, key, value) do
    GenServer.call(via(registry(instance)), {:persist, event, collection, key, value})
  end

  @impl Brook.Storage
  def delete(instance, collection, key) do
    GenServer.call(via(registry(instance)), {:delete, collection, key})
  end

  @impl Brook.Storage
  def get(instance, collection, key) do
    GenServer.call(via(registry(instance)), {:get, collection, key})
  end

  @impl Brook.Storage
  def get_events(instance, collection, key) do
    GenServer.call(via(registry(instance)), {:get_events, collection, key})
  end

  @impl Brook.Storage
  def get_all(instance, collection) do
    GenServer.call(via(registry(instance)), {:get_all, collection})
  end

  @impl Brook.Storage
  def start_link(args) do
    instance = Keyword.fetch!(args, :instance)
    GenServer.start_link(__MODULE__, args, name: via(registry(instance)))
  end

  @impl GenServer
  def init(_args) do
    table = :ets.new(nil, [:set, :protected])

    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_call({:persist, event, collection, key, value}, _from, state) do
    events = get_existing_events(state, {collection, key})
    :ets.insert(state.table, {{collection, key}, value, events ++ [event]})

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:delete, collection, key}, _from, state) do
    :ets.delete(state.table, {collection, key})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:get, collection, key}, _from, state) do
    case :ets.lookup(state.table, {collection, key}) do
      [{_key, value, _events}] -> value
      _ -> nil
    end
    |> ok()
    |> reply(state)
  end

  @impl GenServer
  def handle_call({:get_events, collection, key}, _from, state) do
    {:reply, get_existing_events(state, {collection, key}) |> ok(), state}
  end

  @impl GenServer
  def handle_call({:get_all, collection}, _from, state) do
    :ets.match_object(state.table, {{collection, :_}, :_, :_})
    |> Enum.map(fn {{_collection, key}, value, _events} ->
      {key, value}
    end)
    |> Enum.into(%{})
    |> ok()
    |> reply(state)
  end

  defp get_existing_events(state, key) do
    case :ets.lookup(state.table, key) do
      [] -> []
      [{^key, _value, events}] -> events
    end
  end

  defp ok(value), do: {:ok, value}
  defp reply(value, state), do: {:reply, value, state}
  defp via(registry), do: {:via, Registry, {registry, __MODULE__}}
end
