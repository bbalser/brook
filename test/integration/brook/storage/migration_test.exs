defmodule Brook.Storage.Redis.MigrationTest do
  use ExUnit.Case
  use Divo, services: [:redis]

  alias Brook.Storage.Redis
  alias Brook.Storage.Redis.Migration

  @instance :brook_testing
  @namespace "testing"
  @collection "people"

  setup [:start_redis, :start_local_redix]

  test "converts view state entries to new path", %{redix: redix} do
    view_state = %{"one" => 1, "two" => 2}
    redis_value = %{key: 1, value: view_state}
    Redix.command!(redix, ["SET", "#{@namespace}:#{@collection}:1", :erlang.term_to_binary(redis_value)])

    events = [
      Brook.Event.new(type: "type1", author: "testing", data: 1, create_ts: 0),
      Brook.Event.new(type: "type2", author: "testing", data: 2, create_ts: 1)
    ]

    events
    |> Enum.map(&:erlang.term_to_binary(&1, compressed: 9))
    |> Enum.each(&Redix.command!(redix, ["RPUSH", "#{@namespace}:#{@collection}:1:events", &1]))

    Migration.migrate(@instance, redix, @namespace) |> IO.inspect(label: "output")

    assert {:ok, view_state} == Redis.get(@instance, @collection, 1)
    assert {:ok, events} == Redis.get_events(@instance, @collection, 1)

    assert 0 == Redix.command!(redix, ["EXISTS", "#{@namespace}:#{@collection}:1"])
    assert 0 == Redix.command!(redix, ["EXISTS", "#{@namespace}:#{@collection}:1:events"])
  end

  test "defaults author name if author not present", %{redix: redix} do
    view_state = %{"three" => 3}
    redis_value = %{key: 3, value: view_state}
    event = struct(Brook.Event, type: "type3", data: 3, create_ts: 0) |> Map.delete(:author)

    Redix.command!(redix, ["SET", "#{@namespace}:#{@collection}:3", :erlang.term_to_binary(redis_value)])

    Redix.command!(redix, [
      "RPUSH",
      "#{@namespace}:#{@collection}:3:events",
      :erlang.term_to_binary(event, compressed: 9)
    ])

    Migration.migrate(@instance, redix, @namespace)

    assert {:ok, [%Brook.Event{author: author}]} = Redis.get_events(@instance, @collection, 3)
    assert author == "migrated_default"
  end

  test "defaults creation timestamp if create_ts not present", %{redix: redix} do
    view_state = %{"four" => 4}
    redis_value = %{key: 4, value: view_state}
    event = struct(Brook.Event, type: "type4", data: 4) |> Map.delete(:create_ts)

    Redix.command!(redix, ["SET", "#{@namespace}:#{@collection}:4", :erlang.term_to_binary(redis_value)])

    Redix.command!(redix, [
      "RPUSH",
      "#{@namespace}:#{@collection}:4:events",
      :erlang.term_to_binary(event, compressed: 9)
    ])

    Migration.migrate(@instance, redix, @namespace)

    assert {:ok, [%Brook.Event{create_ts: timestamp}]} = Redis.get_events(@instance, @collection, 4)
    assert timestamp == 0
  end

  defp start_redis(_context) do
    registry_name = Brook.Config.registry(@instance)
    {:ok, registry} = Registry.start_link(name: registry_name, keys: :unique)

    {:ok, redis} =
      Redis.start_link(
        instance: @instance,
        namespace: @namespace,
        redix_args: [host: "localhost"],
        event_limits: %{"restricted" => 5}
      )

    on_exit(fn ->
      kill(redis)
      kill(registry)
    end)

    :ok
  end

  defp start_local_redix(_context) do
    {:ok, redix} = Redix.start_link(host: "localhost")
    Redix.command!(redix, ["FLUSHALL"])

    on_exit(fn -> kill(redix) end)

    [redix: redix]
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
