defmodule Brook.Server do
  use GenServer
  require Logger

  alias Brook.Tracking

  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def start_link(%Brook.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: {:via, Registry, {Brook.Registry, __MODULE__}})
  end

  def init(%Brook.Config{} = config) do
    :ets.new(__MODULE__, [:named_table, :set, :protected])
    Tracking.create_table(config)

    {:ok, config, {:continue, :snapshot_init}}
  end

  def handle_continue(:snapshot_init, %{snapshot: %{module: module} = snapshot_config} = state) do
    interval = Map.get(snapshot_config, :interval, 60)

    load_entries_from_snapshot(module)
    {:ok, ref} = :timer.send_interval(interval * 1_000, self(), :snapshot)

    Logger.info(fn -> "Brook snapshot configured every #{interval} to #{inspect(module)}" end)
    {:noreply, %{state | snapshot_timer: ref}}
  end

  def handle_continue(:snapshot_init, state) do
    {:noreply, state}
  end

  def handle_call({:process, %Brook.Event{} = event}, _from, state) do
    Enum.each(state.event_handlers, fn handler ->
      case apply(handler, :handle_event, [event]) do
        {:create, key, value} -> insert(state, key, value)
        {:merge, key, value} -> merge(state, key, value)
        {:delete, key} -> delete(state, key)
        :discard -> nil
      end
    end)

    {:reply, :ok, %{state | unacked: [{event.ack_ref, event.ack_data} | state.unacked]}}
  end

  def handle_call({:send, type, event}, _from, state) do
    :ok = apply(state.driver.module, :send_event, [type, event])
    {:reply, :ok, state}
  end

  def handle_info(:snapshot, state) do
    Logger.info(fn -> "Snapshotting to event store #{inspect(state.snapshot.module)}" end)

    actions = Tracking.get_actions(state)
    persist_records_in_snapshot(state, actions)
    delete_records_in_snapshot(state, actions)
    Tracking.clear(state)

    ack_events(state)

    {:noreply, state}
  end

  defp ack_events(state) do
    state.unacked
    |> Enum.reverse()
    |> Enum.group_by(fn {ack_ref, _ack_data} -> ack_ref end, fn {_ack_ref, ack_data} -> ack_data end)
    |> Enum.each(fn {ack_ref, ack_datas} ->
      apply(state.driver.module, :ack, [ack_ref, ack_datas])
    end)
  end

  defp persist_records_in_snapshot(state, %{insert: keys}) do
    insertions = Enum.map(keys, fn key -> {key, get(key)} end)

    :ok = apply(state.snapshot.module, :persist, [insertions])
  end

  defp persist_records_in_snapshot(_state, _actions), do: :ok

  defp delete_records_in_snapshot(state, %{delete: keys}) do
    :ok = apply(state.snapshot.module, :delete, [keys])
  end

  defp delete_records_in_snapshot(_state, _actions), do: :ok

  defp insert(config, key, value) do
    :ets.insert(__MODULE__, {key, value})
    Tracking.record_action(config, key, :insert)
  end

  defp merge(config, key, %{} = value) do
    case get(key) do
      nil -> insert(config, key, value)
      existing_value -> insert(config, key, Map.merge(existing_value, value))
    end
  end

  defp merge(config, key, value) when is_list(value) do
    case get(key) do
      nil -> insert(config, key, value)
      existing_value -> insert(config, key, Keyword.merge(existing_value, value))
    end
  end

  defp merge(config, key, function) when is_function(function, 1) do
    insert(config, key, function.(get(key)))
  end

  defp delete(config, key) do
    :ets.delete(__MODULE__, key)
    Tracking.record_action(config, key, :delete)
  end

  defp load_entries_from_snapshot(module) do
    apply(module, :get_latest, [])
    |> Enum.each(fn {key, value} ->
      :ets.insert(__MODULE__, {key, value})
    end)
  end
end
