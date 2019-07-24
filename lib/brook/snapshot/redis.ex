defmodule Brook.Snapshot.Redis do
  use GenServer
  @behaviour Brook.Snapshot

  @type config :: [
          redix_args: keyword(),
          namespace: String.t()
        ]

  @impl Brook.Snapshot
  def store(entries) do
    GenServer.call(via(), {:store, entries})
  end

  @impl Brook.Snapshot
  def get_latest() do
    GenServer.call(via(), :get_latest)
  end

  @spec start_link(config()) :: GenServer.on_start()
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
  def handle_call({:store, entries}, _from, state) do
    entries
    |> Enum.map(fn {key, value} -> {key, %{key: key, value: value}} end)
    |> Enum.each(fn {key, value} ->
      Redix.command!(state.redix, ["SET", "#{state.namespace}:#{key}", :erlang.term_to_binary(value)])
    end)

    reply(:ok, state)
  end

  @impl GenServer
  def handle_call(:get_latest, _from, state) do
    case Redix.command!(state.redix, ["KEYS", "#{state.namespace}:*"]) do
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

  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
  defp reply(reply_value, state), do: {:reply, reply_value, state}
end
