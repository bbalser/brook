defmodule Brook.Storage.RedisTest do
  use ExUnit.Case
  use Divo, services: [:redis]
  use Placebo

  alias Brook.Storage.Redis

  describe "persist/4" do
    setup [:start_redis, :start_local_redix]

    test "will save the key/value in a collection", %{redix: redix} do
      Redis.persist(:event1, "people", "key1", %{one: 1})

      saved_value =
        Redix.command!(redix, ["GET", "testing:people:key1"])
        |> Jason.decode!()
        |> (fn %{"key" => _key, "value" => value} -> value end).()
        |> Jason.decode!()

      assert %{"one" => 1} == saved_value
    end

    test "will append the event to a redis list", %{redix: redix} do
      event1 = %Brook.Event{author: "bob", type: "create", data: %{one: 1}}
      event2 = %Brook.Event{author: "bob", type: "update", data: %{one: 1, two: 2}}

      :ok = Redis.persist(event1, "people", "key1", event1.data)
      :ok = Redis.persist(event2, "people", "key1", event2.data)

      saved_value =
        Redix.command!(redix, ["GET", "testing:people:key1"])
        |> Jason.decode!()
        |> (fn %{"key" => _key, "value" => value} -> value end).()
        |> Jason.decode!()

      assert %{"one" => 1, "two" => 2} == saved_value

      saved_event_list =
        Redix.command!(redix, ["LRANGE", "testing:people:key1:events", 0, -1])
        |> Enum.map(&Brook.Deserializer.deserialize/1)
        |> Enum.map(fn {:ok, decoded_value} -> decoded_value end)

      assert [%{event1 | data: %{"one" => 1}}, %{event2 | data: %{"one" => 1, "two" => 2}}] == saved_event_list
    end

    test "will return an error tuple when redis returns an error" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.persist(:event1, "people", "key1", %{one: 1})
    end
  end

  describe "persist/4 when process is not started" do
    test "will return an error tuple if module is not initialized" do
      assert {:error, Brook.Uninitialized.exception(message: "Elixir.Brook.Storage.Redis is not initialized yet!")} ==
               Redis.persist(:event1, "people", "key1", %{one: 1})
    end
  end

  describe "get/2" do
    setup [:start_redis, :start_local_redix]

    test "will return the value persisted in redis" do
      :ok = Redis.persist(:event1, "people", "key1", %{name: "joe"})

      assert {:ok, %{"name" => "joe"}} == Redis.get("people", "key1")
    end

    test "returns an error tuple when redix returns an error" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.get("people", "key1")
    end
  end

  describe "get_events/2" do
    setup [:start_redis, :start_local_redix]

    test "returns all events for key" do
      event1 = %Brook.Event{author: "steve", type: "create", data: %{one: 1}}
      event2 = %Brook.Event{author: "steve", type: "update", data: %{one: 1, two: 2}}

      :ok = Redis.persist(event1, "people", "key1", event1.data)
      :ok = Redis.persist(event2, "people", "key1", event2.data)

      assert {:ok, [%{event1 | data: %{"one" => 1}}, %{event2 | data: %{"one" => 1, "two" => 2}}]} ==
               Redis.get_events("people", "key1")
    end

    test "returns error tuple when redix returns an error" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.get_events("people", "key1")
    end
  end

  describe "get_all/1" do
    setup [:start_redis, :start_local_redix]

    test "returns all the values in a collection" do
      :ok = Redis.persist(:event1, "people", "key1", "value1")
      :ok = Redis.persist(:event2, "people", "key2", "value2")
      :ok = Redis.persist(:event3, "people", "key3", "value3")

      expected = %{"key1" => "value1", "key2" => "value2", "key3" => "value3"}

      assert {:ok, expected} == Redis.get_all("people")
    end

    test "returns error tuple when redix returns an error" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.get_all("people")
    end

    test "returns empty map when no data available" do
      allow Redix.command(any(), ["KEYS" | any()]), return: {:ok, []}

      assert {:ok, %{}} == Redis.get_all("jerks")
    end
  end

  describe "delete/2" do
    setup [:start_redis, :start_local_redix]

    test "deletes entry in redis" do
      :ok = Redis.persist(:event1, "people", "key1", "value1")
      assert {:ok, "value1"} == Redis.get("people", "key1")

      :ok = Redis.delete("people", "key1")
      assert {:ok, nil} == Redis.get("people", "key1")
    end

    test "return error tuple when redis return error tuple" do
      allow Redix.command(any(), any()), return: {:error, :some_failure}

      assert {:error, :some_failure} == Redis.delete("people", "key")
    end
  end

  defp start_redis(_context) do
    {:ok, registry} = Registry.start_link(name: Brook.Registry, keys: :unique)
    {:ok, redis} = Redis.start_link(namespace: "testing", redix_args: [host: "localhost"])

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
