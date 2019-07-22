defmodule Brook.Server do
  use GenServer
  require Logger

  defmodule State do
    defstruct [:elsa, :kafka_config, :decoder, :event_handlers, :snapshot, :snapshot_state, :snapshot_timer]
  end

  def start_link(%Brook.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: {:via, Registry, {Brook.Registry, __MODULE__}})
  end

  def init(%Brook.Config{} = config) do
    :ets.new(__MODULE__, [:named_table, :set, :protected])

    {:ok, config, {:continue, :snapshot_init}}
  end

  # def handle_continue(:elsa_init, state) do
  #   elsa_config =
  #     [name: :brook_elsa, handler: Brook.Elsa.Handler]
  #     |> Keyword.merge(state.kafka_config)

  #   {:ok, elsa} = Elsa.Group.Supervisor.start_link(elsa_config)
  #   {:noreply, %{state | elsa: elsa}, {:continue, :snapshot_init}}
  # end

  def handle_continue(:snapshot_init, %{snapshot: %{storage: storage} = snapshot_config} = state) do
    init_arg = Map.get(snapshot_config, :init_arg, [])
    interval = Map.get(snapshot_config, :interval, 60)

    {:ok, storage_state} = apply(storage, :init, [init_arg])
    load_entries_from_snapshot(storage, storage_state)
    {:ok, ref} = :timer.send_interval(interval * 1_000, self(), :snapshot)

    Logger.debug(fn -> "Brooke snapshot configured every #{interval} to #{inspect(storage)}" end)
    {:noreply, %{state | snapshot_state: storage_state, snapshot_timer: ref}}
  end

  def handle_continue(:snapshot_init, state) do
    {:noreply, state}
  end

  def handle_call({:process, type, event}, _from, state) do
    decoded_event = apply(state.decoder, :decode, [event])
    handlers = state.event_handlers[type]

    Enum.each(handlers, fn handler ->
      case apply(handler, :handle_event, [type, decoded_event]) do
        {:update, key, value} -> :ets.insert(__MODULE__, {key, value})
        {:delete, key} -> :ets.delete(__MODULE__, key)
        {:discard} -> nil
      end
    end)

    {:reply, :ok, state}
  end

  def handle_info(:snapshot, state) do
    Logger.debug(fn -> "Snapshotting to event store #{inspect(state.snapshot.storage)}" end)

    entries =
      :ets.match_object(__MODULE__, :_)
      |> Enum.into(%{})

    apply(state.snapshot.storage, :store, [entries, state.snapshot_state])

    {:noreply, state}
  end

  defp load_entries_from_snapshot(storage, state) do
    apply(storage, :get_latest, [state])
    |> Enum.each(fn {key, value} ->
      :ets.insert(__MODULE__, {key, value})
    end)
  end
end
