defmodule Brook.WatchTest do
  use ExUnit.Case

  setup do
    {:ok, brook} =
      Brook.start_link(
        handlers: [Test.Event.Handler],
        watches: [
          keys: [{:all, :app_state}],
          handler: Test.Update.Handler,
          handler_init_arg: %{pid: self()},
          interval: 1
        ],
        storage: [
          module: Brook.Storage.Ets,
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
    assert_receive {:update, :all, :app_state, %{"id" => "hot_dogs", "count" => 0}}, 2_000

    :ok = Brook.process(event("UPDATE_APP_STATE", %{"id" => "hot_dogs", "count" => 1}))
    assert_receive {:update, :all, :app_state, %{"id" => "hot_dogs", "count" => 1}}, 2_000
  end

  defp event(type, data) do
    %Brook.Event{type: type, data: data}
  end
end
