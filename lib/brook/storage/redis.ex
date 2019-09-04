defmodule Brook.Storage.Redis do
  @moduledoc """
  Implements the `Brook.Storage` behaviour for the Redis
  key/value storage system, saving the application view state
  as binary encodings of the direct Elixir terms to be saved with
  maximum compression.
  """
  use GenServer
  require Logger
  @behaviour Brook.Storage

  @type config :: [
          redix_args: keyword(),
          namespace: String.t()
        ]

  @impl Brook.Storage
  def persist(event, collection, key, value) do
    namespace = state(:namespace)
    redix = state(:redix)
    Logger.debug(fn -> "#{__MODULE__}: persisting #{collection}:#{key}:#{inspect(value)} to redis" end)

    with {:ok, "OK"} <-
           redis_set(redix, key(namespace, collection, key), :erlang.term_to_binary(%{key: key, value: value})),
         {:ok, _count} <-
           redis_append(redix, events_key(namespace, collection, key), :erlang.term_to_binary(event, compressed: 9)) do
      :ok
    end
  rescue
    ArgumentError -> {:error, not_initialized_exception()}
  end

  @impl Brook.Storage
  def delete(collection, key) do
    namespace = state(:namespace)

    case redis_delete(state(:redix), [key(namespace, collection, key), events_key(namespace, collection, key)]) do
      {:ok, _count} -> :ok
      error_result -> error_result
    end
  end

  @impl Brook.Storage
  def get(collection, key) do
    case redis_get(state(:redix), key(state(:namespace), collection, key)) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, value} ->
        :erlang.binary_to_term(value)
        |> Map.get(:value)
        |> ok()

      error_result ->
        error_result
    end
  end

  @impl Brook.Storage
  def get_all(collection) do
    namespace = state(:namespace)
    redix = state(:redix)

    with {:ok, keys} <- redis_keys(redix, key(namespace, collection, "*")),
         filtered_keys <- Enum.filter(keys, fn key -> !String.ends_with?(key, ":events") end),
         {:ok, binary_values} <- redis_multiget(redix, filtered_keys) do
      binary_values
      |> Enum.map(&:erlang.binary_to_term/1)
      |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
      |> Enum.into(%{})
      |> ok()
    end
  end

  @impl Brook.Storage
  def get_events(collection, key) do
    case redis_get_all(state(:redix), events_key(state(:namespace), collection, key)) do
      {:ok, value} -> {:ok, Enum.map(value, &:erlang.binary_to_term(&1))}
      error_result -> error_result
    end
  end

  @impl Brook.Storage
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via())
  end

  @impl GenServer
  def init(args) do
    redix_args = Keyword.fetch!(args, :redix_args)
    namespace = Keyword.fetch!(args, :namespace)

    :ets.new(__MODULE__, [:set, :protected, :named_table])
    :ets.insert(__MODULE__, {:namespace, namespace})

    {:ok, %{namespace: namespace}, {:continue, {:init, redix_args}}}
  end

  @impl GenServer
  def handle_continue({:init, redix_args}, state) do
    {:ok, pid} = Redix.start_link(redix_args)
    :ets.insert(__MODULE__, {:redix, pid})
    {:noreply, Map.put(state, :redix, pid)}
  end

  defp state(key) do
    case :ets.lookup(__MODULE__, key) do
      [] -> raise not_initialized_exception()
      [{^key, value}] -> value
    end
  end

  defp not_initialized_exception() do
    Brook.Uninitialized.exception(message: "#{__MODULE__} is not initialized yet!")
  end

  defp redis_get(redix, key), do: Redix.command(redix, ["GET", key])
  defp redis_get_all(redix, key), do: Redix.command(redix, ["LRANGE", key, 0, -1])
  defp redis_set(redix, key, value), do: Redix.command(redix, ["SET", key, value])
  defp redis_append(redix, key, value), do: Redix.command(redix, ["RPUSH", key, value])
  defp redis_keys(redix, key), do: Redix.command(redix, ["KEYS", key])
  defp redis_delete(redix, keys), do: Redix.command(redix, ["DEL" | keys])

  defp redis_multiget(_redix, []), do: {:ok, []}
  defp redis_multiget(redix, keys), do: Redix.command(redix, ["MGET" | keys])

  defp ok(value), do: {:ok, value}
  defp key(namespace, collection, key), do: "#{namespace}:#{collection}:#{key}"
  defp events_key(namespace, collection, key), do: "#{namespace}:#{collection}:#{key}:events"
  defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
end
