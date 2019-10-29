defmodule Brook.Storage.Redis.Migration do
  alias Brook.Storage.Redis

  @expiration 60 * 60 * 24 * 7

  def migrate(instance, redix, namespace, event_limits) do
    regex = ~r/^#{namespace}:(?<collection>[[:alnum:]-_]+):(?<key>[[:alnum:]-_]+)$/

    view_state_entries =
      keys(redix, "#{namespace}:*")
      |> Enum.filter(&Regex.match?(regex, &1))
      |> Enum.map(fn key -> Regex.named_captures(regex, key) |> Map.put("redis_key", key) end)
      |> Enum.map(&get_old_view_state(redix, &1))
      |> Enum.map(&get_old_events(redix, event_limits, &1))

    Enum.each(view_state_entries, &save_view_state(instance, &1))
    Enum.each(view_state_entries, &move_old_entry(redix, &1))
  end

  defp keys(redix, pattern), do: Redix.command!(redix, ["KEYS", pattern])

  defp get_old_view_state(redix, %{"redis_key" => redis_key} = view_state) do
    view_entry = Redix.command!(redix, ["GET", redis_key]) |> :erlang.binary_to_term()
    Map.put(view_state, "value", view_entry.value)
  end

  defp get_old_events(redix, event_limits, view_state) do
    events_key = view_state["redis_key"] <> ":events"

    events_by_type =
      Stream.iterate(0, fn x -> x + 1000 end)
      |> Stream.map(fn start -> Redix.command!(redix, ["LRANGE", events_key, start, start + 999]) end)
      |> Stream.take_while(fn list -> length(list) > 0 end)
      |> Stream.map(&binary_to_term/1)
      |> Stream.map(&ensure_event_fields/1)
      |> Enum.reduce(%{}, fn list, acc ->
        Enum.reduce(list, acc, fn event, acc2 ->
          Map.update(acc2, event.type, [event], fn cur -> cur ++ [event] end)
        end)
        |> Enum.map(fn {type, list} ->
          {type, ensure_event_limit(event_limits, type, list)}
        end)
        |> Map.new()
      end)

    Map.put(view_state, "events", Map.values(events_by_type) |> List.flatten())
  end

  defp ensure_event_limit(event_limits, type, list) do
    case Map.get(event_limits, type, :no_limit) do
      :no_limit -> list
      limit -> Enum.drop(list, length(list) - limit)
    end
  end

  defp binary_to_term(list) when is_list(list) do
    Enum.map(list, &:erlang.binary_to_term/1)
  end

  defp save_view_state(instance, view_state) do
    view_state["events"]
    |> Enum.each(&Redis.persist(instance, &1, view_state["collection"], view_state["key"], view_state["value"]))
  end

  defp move_old_entry(redix, view_state) do
    key = view_state["redis_key"]

    commands = [
      ["RENAME", key, "old:" <> key],
      ["EXPIRE", "old:" <> key, @expiration],
      ["RENAME", key <> ":events", "old:" <> key <> ":events"],
      ["EXPIRE", "old:" <> key <> ":events", @expiration]
    ]

    Redix.pipeline!(redix, commands)
  end

  defp ensure_event_fields(list) when is_list(list) do
    Enum.map(list, &ensure_event_fields/1)
  end

  defp ensure_event_fields(event) do
    event
    |> Map.update(:author, "migrated_default", fn author -> author end)
    |> Map.update(:create_ts, 0, fn ts -> ts end)
    |> Map.update(:forwarded, false, fn boolean -> boolean end)
  end
end
