defmodule Brook.Watcher do
  use GenServer
  require Logger

  def start_link(%Brook.Config{} = config) do
    GenServer.start_link(__MODULE__, config, name: via())
  end

  def init(%Brook.Config{watches: watches}) do
    state = %{
      timer_ref: :timer.send_interval(watches.interval * 1000, :poll_keys),
      handler: watches.handler,
      handler_state: handler_init(watches),
      last_values: Enum.map(watches.keys, fn key -> {key, nil} end)
    }

    {:ok, state, {:continue, :poll_keys}}
  end

  def handle_continue(:poll_keys, state), do: {:noreply, update_handlers(state)}

  def handle_info(:poll_keys, state), do: {:noreply, update_handlers(state)}

  defp update_handlers(state) do
    {new_state, new_values} =
      Enum.reduce(state.last_values, {state, []}, fn last_value, {state, values} ->
        {new_state, new_value} = handle_update(state, last_value)
        {new_state, [new_value | values]}
      end)

    Map.put(new_state, :last_values, new_values)
  end

  defp handle_update(state, {key, last_value}) do
    case Brook.get(key) do
      ^last_value ->
        {state, {key, last_value}}

      new_value ->
        {:ok, new_handler_state} = apply(state.handler, :handle_update, [key, new_value, state.handler_state])
        {Map.put(state, :handler_state, new_handler_state), {key, new_value}}
    end
  end

  defp handler_init(watches) do
    {:ok, handler_state} = apply(watches.handler, :init, [Map.get(watches, :handler_init_arg, [])])
    handler_state
  end

  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
end
