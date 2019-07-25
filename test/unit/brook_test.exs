defmodule BrookTest do
  use ExUnit.Case

  setup do
    {:ok, brook} = Brook.start_link(handlers: [Test.Event.Handler])

    on_exit(fn ->
      ref = Process.monitor(brook)
      Process.exit(brook, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)

    [brook: brook]
  end

  test "update store" do
    Brook.process(event("CREATE", %{"id" => 123, "name" => "George"}))

    assert %Test.Event.Data{id: 123, name: "George", started: false} == Brook.get(123)
  end

  test "delete store" do
    Brook.process(event("CREATE", %{"id" => 123, "name" => "George"}))
    Brook.process(event("DELETE", %{"id" => 123}))

    assert nil == Brook.get(123)
  end

  test "unhandle event" do
    assert :discard == Test.Event.Handler.handle_event(event("DISCARD", :some_event))
  end

  defp event(type, data) do
    %Brook.Event{type: type, data: data}
  end
end
