defmodule Brook.IntegrationTest do
  use ExUnit.Case
  use Divo
  import Assertions

  @instance :brook_test

  setup do
    {:ok, redix} = Redix.start_link(host: "localhost")
    Redix.command!(redix, ["FLUSHALL"])

    config = [
      instance: @instance,
      driver: %{
        module: Brook.Driver.Kafka,
        init_arg: [
          endpoints: [localhost: 9092],
          topic: "test",
          group: "test-group",
          consumer_config: [
            begin_offset: :earliest
          ]
        ]
      },
      handlers: [Test.Event.Handler],
      storage: %{
        module: Brook.Storage.Redis,
        init_arg: [redix_args: [host: "localhost"], namespace: "test:snapshot"]
      }
    ]

    {:ok, brook} = Brook.start_link(config)

    on_exit(fn ->
      kill_and_wait(redix)
      kill_and_wait(brook, 10_000)
    end)

    [redix: redix]
  end

  test "brook happy path" do
    Brook.Event.send(@instance, "CREATE", "testing", %{"id" => 123, "name" => "George"})
    Brook.Event.send(@instance, "UPDATE", "testing", %{"id" => 123, "age" => 67})
    Brook.Event.send(@instance, "UPDATE_APP_STATE", "testing", %{"name" => "app_state"})

    assert_async(timeout: 2_000, sleep_time: 200) do
      assert {:ok, %{"id" => 123, "name" => "George", "age" => 67}} == Brook.get(@instance, :all, 123)
    end

    assert_async(timeout: 2_000, sleep_time: 200) do
      expected = %{
        123 => %{"id" => 123, "name" => "George", "age" => 67},
        "app_state" => %{"name" => "app_state"}
      }

      assert expected == Brook.get_all!(@instance, :all)
    end

    assert_async(timeout: 2_000, sleep_time: 200) do
      {:ok, events} = Brook.get_events(@instance, :all, 123)
      assert 2 == length(events)

      create_event = List.first(events)
      assert "CREATE" == create_event.type
      assert %{"id" => 123, "name" => "George"} == create_event.data

      update_event = Enum.at(events, 1)
      assert "UPDATE" == update_event.type
      assert %{"id" => 123, "age" => 67} == update_event.data
    end

    Brook.Event.send(@instance, "DELETE", "testing", %{"id" => 123})

    assert_async(timeout: 2_000, sleep_time: 200) do
      assert {:ok, nil} == Brook.get(@instance, :all, 123)
    end
  end

  test "should be able to view state in event handler" do
    Brook.Event.send(@instance, "CREATE", "testing", %{"id" => 123, "name" => "George"})
    Brook.Event.send(@instance, "READ_VIEW", "testing", %{"id" => 123})

    [{pid, _value}] = Registry.lookup(Brook.Config.registry(@instance), Brook.Server)

    alive? = Process.alive?(pid)
    assert true == alive?

    Process.sleep(5_000)

    alive? = Process.alive?(pid)
    assert true == alive?
  end

  defp kill_and_wait(pid, timeout \\ 1_000) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}, timeout
  end
end
