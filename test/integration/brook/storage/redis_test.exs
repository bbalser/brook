defmodule Brook.Storage.RedisTest do
  use ExUnit.Case
  use Divo, services: [:redis]
  use Placebo

  alias Brook.Storage.Redis

  @instance :brook_test
  @namespace "testing"

  describe "persist/4" do
    setup [:start_redis, :start_local_redix]

    test "will save the key/value in a collection", %{redix: redix} do
      event = Brook.Event.new(type: "create", author: "testing", data: "data")
      Redis.persist(@instance, event, "people", "key1", %{one: 1})

      saved_value =
        Redix.command!(redix, ["GET", "#{@namespace}:state:people:key1"])
        |> Jason.decode!()
        |> (fn %{"key" => _key, "value" => value} -> value end).()
        |> Jason.decode!()

      assert %{"one" => 1} == saved_value
    end

    test "will append the event to a redis list", %{redix: redix} do
      event1 = Brook.Event.new(author: "bob", type: "create", data: %{"one" => 1})
      event2 = Brook.Event.new(author: "bob", type: "update", data: %{"one" => 1, "two" => 2})

      :ok = Redis.persist(@instance, event1, "people", "key1", event1.data)
      :ok = Redis.persist(@instance, event2, "people", "key1", event2.data)

      saved_value =
        Redix.command!(redix, ["GET", "#{@namespace}:state:people:key1"])
        |> Jason.decode!()
        |> (fn %{"key" => _key, "value" => value} -> value end).()
        |> Jason.decode!()

      assert %{"one" => 1, "two" => 2} == saved_value

      create_event_list =
        Redix.command!(redix, ["LRANGE", "#{@namespace}:events:people:key1:create", 0, -1])
        |> Enum.map(&:zlib.gunzip/1)
        |> Enum.map(&Brook.Deserializer.deserialize/1)
        |> Enum.map(fn {:ok, decoded_value} -> decoded_value end)

      assert [event1] == create_event_list

      update_event_list =
        Redix.command!(redix, ["LRANGE", "#{@namespace}:events:people:key1:update", 0, -1])
        |> Enum.map(&:zlib.gunzip/1)
        |> Enum.map(&Brook.Deserializer.deserialize/1)
        |> Enum.map(fn {:ok, decoded_value} -> decoded_value end)

      assert [event2] == update_event_list
    end

    test "will return an error tuple when redis returns an error" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      event = Brook.Event.new(type: "create", author: "testing", data: "data")
      assert {:error, :some_failure} == Redis.persist(@instance, event, "people", "key1", %{one: 1})
    end

    test "will only save configured number for event with restrictions" do
      Enum.each(1..10, fn i ->
        create_event = Brook.Event.new(type: "create", author: "testing", data: i)
        Redis.persist(@instance, create_event, "people", "key4", %{"name" => "joe"})
        restricted_event = Brook.Event.new(type: "restricted", author: "testing", data: i)
        Redis.persist(@instance, restricted_event, "people", "key4", %{"name" => "joe"})
      end)

      {:ok, events} = Redis.get_events(@instance, "people", "key4")
      grouped_events = Enum.group_by(events, fn event -> event.type end)

      assert 10 == length(grouped_events["create"])
      assert 5 == length(grouped_events["restricted"])
      assert [6, 7, 8, 9, 10] == Enum.map(grouped_events["restricted"], fn x -> x.data end)
    end
  end

  describe "get/2" do
    setup [:start_redis, :start_local_redix]

    test "will return the value persisted in redis" do
      event = Brook.Event.new(type: "create", author: "testing", data: :data1)
      :ok = Redis.persist(@instance, event, "people", "key1", %{name: "joe"})

      assert {:ok, %{"name" => "joe"}} == Redis.get(@instance, "people", "key1")
    end

    test "returns an error tuple when redix returns an error" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.get(@instance, "people", "key1")
    end
  end

  describe "get_events/2" do
    setup [:start_redis, :start_local_redix]

    test "returns all events for key" do
      event1 = Brook.Event.new(author: "steve", type: "create", data: %{"one" => 1}, create_ts: 0)
      event2 = Brook.Event.new(author: "steve", type: "update", data: %{"one" => 1, "two" => 2}, create_ts: 1)

      :ok = Redis.persist(@instance, event1, "people", "key1", event1.data)
      :ok = Redis.persist(@instance, event2, "people", "key1", event2.data)

      assert {:ok, [event1, event2]} ==
               Redis.get_events(@instance, "people", "key1")
    end

    test "returns error tuple when redix returns an error" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.get_events(@instance, "people", "key1")
    end

    test "returns an error when LRANGE call fails" do
      allow Redix.command(any(), ["KEYS" | any()]), return: {:ok, ["one", "two", "three"]}
      allow Redix.command(any(), ["LRANGE" | any()]), seq: [{:ok, [:event]}, {:error, :some_failure}]

      assert {:error, :some_failure} == Redis.get_events(@instance, "people", "key1")
    end

    test "return an error when deserialize fails" do
      allow Redix.command(any(), ["KEYS" | any()]), return: {:ok, ["one", "two", "three"]}
      allow Redix.command(any(), ["LRANGE" | any()]), return: {:ok, [:zlib.gzip("one")]}
      allow Brook.Deserializer.deserialize(any()), seq: [{:ok, :deserialized}, {:error, :deserialize_error}]

      assert {:error, :deserialize_error} == Redis.get_events(@instance, "people", "key1")
    end
  end

  describe "get_all/1" do
    setup [:start_redis, :start_local_redix]

    test "returns all the values in a collection" do
      event = Brook.Event.new(type: "create", author: "testing", data: "data")
      :ok = Redis.persist(@instance, event, "people", "key1", "value1")
      :ok = Redis.persist(@instance, event, "people", "key2", "value2")
      :ok = Redis.persist(@instance, event, "people", "key3", "value3")

      expected = %{"key1" => "value1", "key2" => "value2", "key3" => "value3"}

      assert {:ok, expected} == Redis.get_all(@instance, "people")
    end

    test "returns error tuple when redix returns an error" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.get_all(@instance, "people")
    end

    test "returns empty map when no data available" do
      allow Redix.command(any(), ["KEYS" | any()]), return: {:ok, []}

      assert {:ok, %{}} == Redis.get_all(@instance, "jerks")
    end
  end

  describe "delete/2" do
    setup [:start_redis, :start_local_redix]

    test "deletes entry in redis" do
      event = Brook.Event.new(type: "create", author: "testing", data: "data1")
      :ok = Redis.persist(@instance, event, "people", "key1", "value1")
      assert {:ok, "value1"} == Redis.get(@instance, "people", "key1")

      :ok = Redis.delete(@instance, "people", "key1")
      assert {:ok, nil} == Redis.get(@instance, "people", "key1")
      assert {:ok, []} == Redis.get_events(@instance, "people", "key1")
    end

    test "return error tuple when redis return error tuple" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.delete(@instance, "people", "key")
    end
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
