defmodule BrookTest do
  use ExUnit.Case

  setup do
    {:ok, brook} = Brook.start_link(endpoints: [localhost: 9094], handlers: [Test.Event.Handler])

    on_exit(fn ->
      ref = Process.monitor(brook)
      Process.exit(brook, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)

    [brook: brook]
  end

  test "update store", %{brook: brook} do
    Brook.process(brook, :create, %{"id" => 123, "name" => "George"})

    assert %Test.Event.Data{id: 123, name: "George", started: false} == Brook.get(123)
  end

  test "delete store", %{brook: brook} do
    Brook.process(brook, :create, %{"id" => 123, "name" => "George"})
    Brook.process(brook, :delete, %{"id" => 123})

    assert nil == Brook.get(123)
  end
end
