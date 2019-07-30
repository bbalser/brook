defmodule Brook.Storage.Redis do
  use GenServer
  require Logger
  @behaviour Brook.Storage

  @type config :: [
          redix_args: keyword(),
          namespace: String.t()
        ]

  @impl Brook.Storage
  def persist(event, key, value) do
    GenServer.call(via(), {:persist, event, key, value})
  end

  @impl Brook.Storage
  def delete(keys) do
    GenServer.call(via(), {:delete, keys})
  end

  @impl Brook.Storage
  def get(key) do
    GenServer.call(via(), {:get, key})
  end

  @impl Brook.Storage
  def get_events(key) do
    GenServer.call(via(), {:get_events, key})
  end

  @impl Brook.Storage
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via())
  end

  @impl GenServer
  def init(args) do
    redix_args = Keyword.fetch!(args, :redix_args)
    namespace = Keyword.fetch!(args, :namespace)

    {:ok, %{namespace: namespace}, {:continue, {:init, redix_args}}}
  end

  @impl GenServer
  def handle_continue({:init, redix_args}, state) do
    {:ok, pid} = Redix.start_link(redix_args)
    {:noreply, Map.put(state, :redix, pid)}
  end

  @impl GenServer
  def handle_call({:persist, event, key, value}, _from, state) do
    Logger.debug(fn -> "#{__MODULE__}: persisting #{key}:#{inspect(value)} to redis" end)

    Redix.command!(state.redix, ["SET", key(state, key), :erlang.term_to_binary(value)])
    Redix.command!(state.redix, ["RPUSH", events_key(state, key), :erlang.term_to_binary(event)])

    reply(:ok, state)
  end

  @impl GenServer
  def handle_call({:delete, key}, _from, state) do
    Redix.command!(state.redix, ["DEL", key(state, key), events_key(state, key)])

    reply(:ok, state)
  end

  @impl GenServer
  def handle_call({:get, key}, _from, state) do
    case Redix.command!(state.redix, ["GET", key(state, key)]) do
      nil -> nil
      value -> :erlang.binary_to_term(value)
    end
    |> reply(state)
  end

  @impl GenServer
  def handle_call({:get_events, key}, _from, state) do
    case Redix.command!(state.redix, ["LRANGE", events_key(state, key), 0, -1]) do
      nil -> nil
      value -> Enum.map(value, &:erlang.binary_to_term(&1))
    end
    |> reply(state)
  end

  @impl GenServer
  def handle_call(:get_latest, _from, state) do
    case Redix.command!(state.redix, ["KEYS", key(state, "*")]) do
      [] ->
        []

      keys ->
        Redix.command!(state.redix, ["MGET" | keys])
        |> Enum.map(&:erlang.binary_to_term/1)
        |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
        |> Enum.into(%{})
    end
    |> reply(state)
  end

  defp key(state, key), do: "#{state.namespace}:#{key}"
  defp events_key(state, key), do: "#{state.namespace}:#{key}:events"
  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
  defp reply(reply_value, state), do: {:reply, reply_value, state}
end
