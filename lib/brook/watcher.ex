defmodule Brook.Watcher do
  use GenServer
  require Logger

  def start_link(%Brook.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: via())
  end

  def init(%Brook.Config{watches: watches} = config) do
    state = %{
      timer_ref: :timer.send_interval(watches.interval * 1000, :poll_keys),
      handler: watches.handler,
      last_values: Enum.map(watches.keys, fn key -> {key, nil} end)
    }

    {:ok, state, {:continue, :poll_keys}}
  end

  def handle_continue(:poll_keys, state), do: {:noreply, update_handlers(state)}

  def handle_info(:poll_keys, state), do: {:noreply, update_handlers(state)}

  defp update_handlers(state) do
    new_values = Enum.map(state.last_values, &handle_update(state, &1))

    Map.put(state, :last_values, new_values)
  end

  defp handle_update(state, {key, last_value}) do
    case Brook.get(key) do
      ^last_value ->
        {key, last_value}

      new_value ->
        apply(state.handler, :handle_update, [key, new_value])
        {key, new_value}
    end
  end

  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
end
