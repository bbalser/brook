defmodule Brook.Storage.Redis.Migration do
  alias Brook.Storage.Redis

  @expiration 60 * 60 * 24 * 7

  def migrate(instance, redix, namespace) do
    regex = ~r/^#{namespace}:(?<collection>[[:alnum:]-_]+):(?<key>[[:alnum:]-_]+)$/

    view_state_entries =
      keys(redix, "#{namespace}:*")
      |> Enum.filter(&Regex.match?(regex, &1))
      |> Enum.map(fn key -> Regex.named_captures(regex, key) |> Map.put("redis_key", key) end)
      |> Enum.map(&get_old_view_state(redix, &1))
      |> Enum.map(&get_old_events(redix, &1))

    Enum.each(view_state_entries, &save_view_state(instance, &1))
    Enum.each(view_state_entries, &move_old_entry(redix, &1))
  end

  defp keys(redix, pattern), do: Redix.command!(redix, ["KEYS", pattern])

  defp get_old_view_state(redix, %{"redis_key" => redis_key} = view_state) do
    view_entry = Redix.command!(redix, ["GET", redis_key]) |> :erlang.binary_to_term()
    Map.put(view_state, "value", view_entry.value)
  end

  defp get_old_events(redix, view_state) do
    events_key = view_state["redis_key"] <> ":events"

    old_events =
      Redix.command!(redix, ["LRANGE", events_key, 0, -1])
      |> Enum.map(&:erlang.binary_to_term/1)

    Map.put(view_state, "events", old_events)
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
end
