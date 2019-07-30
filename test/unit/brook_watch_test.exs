defmodule Brook.WatchTest do
  use ExUnit.Case

  defmodule MyTest.AppStateHandler do
    def handle_update(key, state) do
      pid = Agent.get(Brook.WatchTest, fn s -> s end)
      send(pid, {:watch_handler, key, state})
      :ok
    end
  end

  setup do
    test_process = self()
    Agent.start_link(fn -> test_process end, name: __MODULE__)

    {:ok, brook} =
      Brook.start_link(
        handlers: [Test.Event.Handler],
        watches: [
          keys: [:app_state],
          handler: MyTest.AppStateHandler,
          interval: 1
        ],
        storage: [
          module: Brook.Test.Storage.Ets,
          init_arg: []
        ]
      )

    on_exit(fn ->
      ref = Process.monitor(brook)
      Process.exit(brook, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)

    [brook: brook]
  end

  test "updates to app state call the handler" do
    :ok = Brook.process(event("UPDATE_APP_STATE", %{"id" => "hot_dogs", "count" => 0}))
    assert_receive {:watch_handler, :app_state, %{"id" => "hot_dogs", "count" => 0}}, 2_000

    :ok = Brook.process(event("UPDATE_APP_STATE", %{"id" => "hot_dogs", "count" => 1}))
    assert_receive {:watch_handler, :app_state, %{"id" => "hot_dogs", "count" => 1}}, 2_000
  end

  # Move to test helper
  defp event(type, data) do
    %Brook.Event{type: type, data: data}
  end
end
