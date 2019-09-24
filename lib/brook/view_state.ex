defmodule Brook.ViewState do
  require Logger

  @delete_marker :"$delete_me"

  def init(instance) do
    :ets.new(table(instance), [:set, :protected, :named_table])
  end

  @spec get(Brook.instance(), Brook.view_collection(), Brook.view_key()) ::
          {:ok, Brook.view_value()} | {:error, Brook.reason()}
  def get(instance, collection, key) do
    case :ets.lookup(table(instance), {collection, key}) do
      [] ->
        storage = Brook.Config.storage(instance)
        Logger.debug(fn -> "#{__MODULE__}: Retrieving #{collection}:#{key} from storage(#{storage.module})" end)
        apply(storage.module, :get, [instance, collection, key])

      [{_, @delete_marker}] ->
        {:ok, nil}

      [{_, value}] ->
        {:ok, value}
    end
  rescue
    e -> raise Brook.Uninitialized, message: inspect(e)
  end

  @spec get_all(Brook.instance(), Brook.view_collection()) ::
          {:ok, %{required(Brook.view_key()) => Brook.view_value()}} | {:error, Brook.reason()}
  def get_all(instance, collection) do
    storage = Brook.Config.storage(instance)

    with {:ok, persisted_entries} <- apply(storage.module, :get_all, [instance, collection]),
         cached_entries <- get_all_cached_entries(instance, collection) do
      {:ok, Map.merge(persisted_entries, cached_entries)}
    end
  end

  @spec create(Brook.view_collection(), Brook.view_key(), Brook.view_value()) :: :ok
  def create(collection, key, value) do
    assert_environment()
    :ets.insert(table(instance()), {{collection, key}, value})
    :ok
  end

  @spec merge(Brook.view_collection(), Brook.view_key(), Brook.view_value()) :: :ok
  def merge(collection, key, %{} = value) do
    merged_value = do_merge(collection, key, value, &Map.merge(&1, value))
    create(collection, key, merged_value)
  end

  def merge(collection, key, value) when is_list(value) do
    merged_value = do_merge(collection, key, value, &Keyword.merge(&1, value))
    create(collection, key, merged_value)
  end

  def merge(collection, key, function) when is_function(function) do
    merged_value = do_merge(collection, key, nil, function)
    create(collection, key, merged_value)
  end

  @spec delete(Brook.view_collection(), Brook.view_key()) :: :ok
  def delete(collection, key) do
    assert_environment()
    :ets.insert(table(instance()), {{collection, key}, @delete_marker})
    :ok
  end

  def commit(instance) do
    current_event = Process.get(:brook_current_event)

    :ets.match_object(table(instance), :_)
    |> Enum.each(fn {{collection, key}, value} ->
      persist(instance, current_event, collection, key, value)
    end)

    :ets.delete_all_objects(table(instance))
  end

  def rollback(instance) do
    :ets.delete_all_objects(table(instance))
  end

  defp assert_environment() do
    assert_event()
    assert_instance()
  end

  defp assert_instance() do
    case Process.get(:brook_instance) != nil do
      false ->
        raise Brook.InvalidInstance,
          message: "No Instance found: can only be called in Brook.Event.Handler implementation"

      true ->
        true
    end
  end

  defp assert_event() do
    case Process.get(:brook_current_event) != nil do
      false ->
        raise Brook.InvalidEvent, message: "No Event Found: can only be called in Brook.Event.Handler implementation"

      true ->
        true
    end
  end

  defp persist(instance, _event, collection, key, @delete_marker) do
    storage = Brook.Config.storage(instance)
    :ok = apply(storage.module, :delete, [instance, collection, key])
  end

  defp persist(instance, event, collection, key, value) do
    storage = Brook.Config.storage(instance)
    :ok = apply(storage.module, :persist, [instance, event, collection, key, value])
  end

  defp do_merge(collection, key, default, function) when is_function(function, 1) do
    assert_environment()

    case get(instance(), collection, key) do
      {:ok, nil} -> default
      {:ok, old_value} -> function.(old_value)
      {:error, reason} -> raise RuntimeError, message: inspect(reason)
    end
  end

  defp get_all_cached_entries(instance, requested_collection) do
    :ets.match_object(table(instance), :_)
    |> Enum.filter(fn {{collection, _key}, _value} -> collection == requested_collection end)
    |> Enum.map(fn {{_collection, key}, value} ->
      case value == @delete_marker do
        true -> {key, nil}
        false -> {key, value}
      end
    end)
    |> Enum.into(%{})
  end

  defp instance(), do: Process.get(:brook_instance)
  defp table(instance), do: :"brook_view_state_stage_#{instance}"
end
