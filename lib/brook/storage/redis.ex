defmodule Brook.Storage.Redis do
  @moduledoc """
  Implements the `Brook.Storage` behaviour for the Redis
  key/value storage system, saving the application view state
  as binary encodings of the direct Elixir terms to be saved with
  maximum compression.
  """
  use GenServer
  require Logger
  import Brook.Config, only: [registry: 1, put: 3, get: 2]
  @behaviour Brook.Storage

  @type config :: [
          redix_args: keyword(),
          namespace: String.t()
        ]

  @impl Brook.Storage
  def persist(instance, event, collection, key, value) do
    %{redix: redix, namespace: namespace} = state(instance)
    Logger.debug(fn -> "#{__MODULE__}: persisting #{collection}:#{key}:#{inspect(value)} to redis" end)

    with {:ok, serialized_event} <- Brook.Serializer.serialize(event),
         gzipped_serialized_event <- :zlib.gzip(serialized_event),
         {:ok, serialized_value} <- Brook.Serializer.serialize(value),
         {:ok, "OK"} <-
           redis_set(
             redix,
             key(namespace, collection, key),
             Jason.encode!(%{"key" => key, "value" => serialized_value})
           ),
         {:ok, _count} <-
           redis_append(redix, events_key(namespace, collection, key, event.type), gzipped_serialized_event) do
      :ok
    end
  rescue
    ArgumentError -> {:error, not_initialized_exception()}
  end

  @impl Brook.Storage
  def delete(instance, collection, key) do
    %{redix: redix, namespace: namespace} = state(instance)

    with {:ok, event_keys} <- redis_keys(redix, events_key(namespace, collection, key, "*")),
         {:ok, _count} <- redis_delete(redix, [key(namespace, collection, key) | event_keys]) do
      :ok
    end
  end

  @impl Brook.Storage
  def get(instance, collection, key) do
    %{redix: redix, namespace: namespace} = state(instance)

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
  def get_all(instance, collection) do
    %{redix: redix, namespace: namespace} = state(instance)

    with {:ok, keys} <- redis_keys(redix, key(namespace, collection, "*")),
         {:ok, encoded_values} <- redis_multiget(redix, keys),
         {:ok, decoded_values} <- safe_map(encoded_values, &Jason.decode/1) do
      decoded_values
      |> Enum.map(&deserialize_data/1)
      |> Enum.into(%{})
      |> ok()
    end
  end

  @impl Brook.Storage
  def get_events(instance, collection, key) do
    %{redix: redix, namespace: namespace} = state(instance)

    with {:ok, event_keys} <- redis_keys(redix, events_key(namespace, collection, key, "*")),
         {:ok, nested_events} <- safe_map(event_keys, &redis_get_all(redix, &1)),
         compressed_events <- List.flatten(nested_events),
         serialized_events <- Enum.map(compressed_events, &:zlib.gunzip/1),
         {:ok, events} <- safe_map(serialized_events, &Brook.Deserializer.deserialize/1) do
      events
      |> Enum.sort_by(fn event -> event.create_ts end)
      |> ok()
    end
  end

  @impl Brook.Storage
  def start_link(args) do
    instance = Keyword.fetch!(args, :instance)
    GenServer.start_link(__MODULE__, args, name: via(registry(instance)))
  end

  @impl GenServer
  def init(args) do
    instance = Keyword.fetch!(args, :instance)
    redix_args = Keyword.fetch!(args, :redix_args)
    namespace = Keyword.fetch!(args, :namespace)

    {:ok, redix} = Redix.start_link(redix_args)

    put(instance, __MODULE__, %{namespace: namespace, redix: redix})

    {:ok, %{namespace: namespace, redix: redix}}
  end

  defp state(instance) do
    case get(instance, __MODULE__) do
      {:ok, value} -> value
      :error -> raise not_initialized_exception()
    end
  end

  defp safe_map(list, function) do
    Enum.reduce_while(list, {:ok, []}, fn value, {:ok, list} ->
      case function.(value) do
        {:ok, result} -> {:cont, {:ok, [result | list]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
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
  defp key(namespace, collection, key), do: "#{namespace}:state:#{collection}:#{key}"
  defp events_key(namespace, collection, key, event_type), do: "#{namespace}:events:#{collection}:#{key}:#{event_type}"
  defp via(registry), do: {:via, Registry, {registry, __MODULE__}}

  defp deserialize_data(%{"key" => key, "value" => value}) do
    {:ok, deserialized_value} = Brook.Deserializer.deserialize(value)
    {key, deserialized_value}
  end
end
