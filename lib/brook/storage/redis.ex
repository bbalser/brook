defmodule Brook.Storage.Redis do
  use GenServer
  require Logger
  @behaviour Brook.Storage

  @type config :: [
          redix_args: keyword(),
          namespace: String.t()
        ]

  @impl Brook.Storage
  def persist(event, collection, key, value) do
    GenServer.call(via(), {:persist, event, collection, key, value})
  end

  @impl Brook.Storage
  def delete(collection, key) do
    GenServer.call(via(), {:delete, collection, key})
  end

  @impl Brook.Storage
  def get(collection, key) do
    GenServer.call(via(), {:get, collection, key})
  end

  @impl Brook.Storage
  def get_events(collection, key) do
    GenServer.call(via(), {:get_events, collection, key})
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
  def handle_call({:persist, event, collection, key, value}, _from, state) do
    Logger.debug(fn -> "#{__MODULE__}: persisting #{collection}:#{key}:#{inspect(value)} to redis" end)

    Redix.command!(state.redix, ["SET", key(state, collection, key), :erlang.term_to_binary(value)])

    Redix.command!(state.redix, [
      "RPUSH",
      events_key(state, collection, key),
      :erlang.term_to_binary(event, compressed: 9)
    ])

    reply(:ok, state)
  end

  @impl GenServer
  def handle_call({:delete, collection, key}, _from, state) do
    Redix.command!(state.redix, ["DEL", key(state, collection, key), events_key(state, collection, key)])

    reply(:ok, state)
  end

  @impl GenServer
  def handle_call({:get, collection, key}, _from, state) do
    case Redix.command!(state.redix, ["GET", key(state, collection, key)]) do
      nil -> nil
      value -> :erlang.binary_to_term(value)
    end
    |> reply(state)
  end

  @impl GenServer
  def handle_call({:get_events, collection, key}, _from, state) do
    case Redix.command!(state.redix, ["LRANGE", events_key(state, collection, key), 0, -1]) do
      nil -> nil
      value -> Enum.map(value, &:erlang.binary_to_term(&1))
    end
    |> reply(state)
  end

  defp key(state, collection, key), do: "#{state.namespace}:#{collection}:#{key}"
  defp events_key(state, collection, key), do: "#{state.namespace}:#{collection}:#{key}:events"
  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
  defp reply(reply_value, state), do: {:reply, reply_value, state}
end
