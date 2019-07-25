defmodule Brook.Server do
  use GenServer
  require Logger

  alias Brook.Tracking

  defmodule State do
    defstruct [:elsa, :kafka_config, :decoder, :event_handlers, :snapshot, :snapshot_state, :snapshot_timer]
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

    Logger.debug(fn -> "Brook snapshot configured every #{interval} to #{inspect(module)}" end)
    {:noreply, %{state | snapshot_timer: ref}}
  end

  def handle_continue(:snapshot_init, state) do
    {:noreply, state}
  end

  def handle_call({:process, %Brook.Event{} = event}, _from, state) do
    new_event = Brook.Event.update_data(event, fn data -> apply(state.decoder, :decode, [data]) end)

    Enum.each(state.event_handlers, fn handler ->
      case apply(handler, :handle_event, [new_event]) do
        {:update, key, value} -> insert(state, key, value)
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
    Logger.debug(fn -> "Snapshotting to event store #{inspect(state.snapshot.module)}" end)

    entries =
      :ets.match_object(__MODULE__, :_)
      |> Enum.into(%{})

    :ok = apply(state.snapshot.module, :store, [entries])

    state.unacked
    |> Enum.reverse()
    |> Enum.group_by(fn {ack_ref, _ack_data} -> ack_ref end, fn {_ack_ref, ack_data} -> ack_data end)
    |> Enum.each(fn {ack_ref, ack_datas} ->
      apply(state.driver.module, :ack, [ack_ref, ack_datas])
    end)

    {:noreply, state}
  end

  defp insert(config, key, value) do
    :ets.insert(__MODULE__, {key, value})
    Tracking.record_action(config, key, :insert)
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
