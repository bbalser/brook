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
  def persist(registry, event, collection, key, value) do
    %{redix: redix, namespace: namespace} = state(registry)
    Logger.debug(fn -> "#{__MODULE__}: persisting #{collection}:#{key}:#{inspect(value)} to redis" end)

    with {:ok, serialized_event} <- Brook.Serializer.serialize(event),
         gzipped_serialized_event <- :zlib.gzip(serialized_event),
         {:ok, serialized_value} <- Brook.Serializer.serialize(value),
         {:ok, "OK"} <-
           redis_set(redix, key(namespace, collection, key), Jason.encode!(%{key: key, value: serialized_value})),
         {:ok, _count} <-
           redis_append(redix, events_key(namespace, collection, key), gzipped_serialized_event) do
      :ok
    end
  rescue
    ArgumentError -> {:error, not_initialized_exception()}
  end

  @impl Brook.Storage
  def delete(registry, collection, key) do
    %{redix: redix, namespace: namespace} = state(registry)

    case redis_delete(redix, [key(namespace, collection, key), events_key(namespace, collection, key)]) do
      {:ok, _count} -> :ok
      error_result -> error_result
    end
  end

  @impl Brook.Storage
  def get(registry, collection, key) do
    %{redix: redix, namespace: namespace} = state(registry)

    case redis_get(redix, key(namespace, collection, key)) do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, value} ->
        value
        |> Jason.decode!()
        |> Map.get("value")
        |> Brook.Deserializer.deserialize()

      error_result ->
        error_result
    end
  end

  @impl Brook.Storage
  def get_all(registry, collection) do
    %{redix: redix, namespace: namespace} = state(registry)

    with {:ok, keys} <- redis_keys(redix, key(namespace, collection, "*")),
         filtered_keys <- Enum.filter(keys, fn key -> !String.ends_with?(key, ":events") end),
         {:ok, encoded_values} <- redis_multiget(redix, filtered_keys) do
      encoded_values
      |> Enum.map(&Jason.decode!/1)
      |> Enum.map(&deserialize_data/1)
      |> Enum.into(%{})
      |> ok()
    end
  end

  @impl Brook.Storage
  def get_events(registry, collection, key) do
    %{redix: redix, namespace: namespace} = state(registry)

    case redis_get_all(redix, events_key(namespace, collection, key)) do
      {:ok, events} ->
        events
        |> Enum.map(&:zlib.gunzip/1)
        |> Enum.map(&Brook.Deserializer.deserialize/1)
        |> Enum.map(fn {:ok, event} -> event end)
        |> ok()

      error_result ->
        error_result
    end
  end

  @impl Brook.Storage
  def start_link(args) do
    registry = Keyword.fetch!(args, :registry)
    GenServer.start_link(__MODULE__, args, name: via(registry))
  end

  @impl GenServer
  def init(args) do
    registry = Keyword.fetch!(args, :registry)
    redix_args = Keyword.fetch!(args, :redix_args)
    namespace = Keyword.fetch!(args, :namespace)

    {:ok, redix} = Redix.start_link(redix_args)

    Registry.put_meta(registry, __MODULE__, %{namespace: namespace, redix: redix})

    {:ok, %{namespace: namespace, redix: redix}}
  end

  defp state(registry) do
    case Registry.meta(registry, __MODULE__) do
      {:ok, value} -> value
      :error -> raise not_initialized_exception()
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
  defp via(registry), do: {:via, Registry, {registry, __MODULE__}}

  defp deserialize_data(%{"key" => key, "value" => value}) do
    {:ok, deserialized_value} = Brook.Deserializer.deserialize(value)
    {key, deserialized_value}
  end
end
