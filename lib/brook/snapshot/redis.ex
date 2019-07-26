defmodule Brook.Snapshot.Redis do
  use GenServer
  require Logger
  @behaviour Brook.Snapshot

  @type config :: [
          redix_args: keyword(),
          namespace: String.t()
        ]

  @impl Brook.Snapshot
  def persist(records) do
    GenServer.call(via(), {:persist, records})
  end

  @impl Brook.Snapshot
  def delete(keys) do
    GenServer.call(via(), {:delete, keys})
  end

  @impl Brook.Snapshot
  def get_latest() do
    GenServer.call(via(), :get_latest)
  end

  @impl Brook.Snapshot
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
  def handle_call({:persist, []}, _from, state), do: reply(:ok, state)

  @impl GenServer
  def handle_call({:persist, records}, _from, state) do
    Logger.debug(fn -> "#{__MODULE__}: persisting #{length(records)} to redis" end)

    redix_values =
      records
      |> Enum.map(fn {key, value} -> {key(state, key), %{key: key, value: value}} end)
      |> Enum.flat_map(fn {key, value} -> [key, :erlang.term_to_binary(value)] end)

    Redix.command!(state.redix, ["MSET" | redix_values])

    reply(:ok, state)
  end

  @impl GenServer
  def handle_call({:delete, []}, _from, state), do: reply(:ok, state)

  @impl GenServer
  def handle_call({:delete, keys}, _from, state) do
    Logger.debug(fn -> "#{__MODULE__}: deleting #{length(keys)} from redis" end)

    redix_keys =
      keys
      |> Enum.map(fn key -> key(state, key) end)

    Redix.command!(state.redix, ["DEL" | redix_keys])

    reply(:ok, state)
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
  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
  defp reply(reply_value, state), do: {:reply, reply_value, state}
end
