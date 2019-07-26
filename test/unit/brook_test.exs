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

  test "creat entry in store" do
    Brook.process(event("CREATE", %{"id" => 123, "name" => "George"}))

    assert %{"id" => 123, "name" => "George"} == Brook.get(123)
  end

  test "delete store" do
    Brook.process(event("CREATE", %{"id" => 123, "name" => "George"}))
    Brook.process(event("DELETE", %{"id" => 123}))

    assert nil == Brook.get(123)
  end

  test "merge map into view state" do
    Brook.process(event("CREATE", %{"id" => 1, "name" => "Brody", "age" => 21}))
    Brook.process(event("UPDATE", %{"id" => 1, "age" => 22, "married" => true}))

    assert %{"id" => 1, "name" => "Brody", "age" => 22, "married" => true} == Brook.get(1)
  end

  test "merge map into non existant state" do
    Brook.process(event("UPDATE", %{"id" => 1, "name" => "Brody"}))

    assert %{"id" => 1, "name" => "Brody"} == Brook.get(1)
  end

  test "merge keyword list into view state" do
    Brook.process(event("CREATE", id: 1, name: "Jeff", age: 21))
    Brook.process(event("UPDATE", id: 1, age: 22, married: true))

    assert Keyword.equal?([id: 1, name: "Jeff", age: 22, married: true], Brook.get(1))
  end

  test "merge keyword list into not existent state" do
    Brook.process(event("UPDATE", id: 1, age: 22, married: true))

    assert Keyword.equal?([id: 1, age: 22, married: true], Brook.get(1))
  end

  test "merge using function into view state" do
    Brook.process(event("CREATE", %{"id" => 1, "total" => 10}))
    Brook.process(event("ADD", %{"id" => 1, "add" => 5}))

    assert %{"id" => 1, "total" => 15} == Brook.get(1)
  end

  # test "raises exception when attempting to merge unknown types without a function" do
  #   Brook.process(event("STORE_LIST", [1, 2, 3, 4]))

  #   assert_raise Brook.UnsupportedMerge, "unable to merge #{inspect([4, 5, 6])} into #{inspect([1, 2, 3, 4])}", fn ->
  #     Brook.process(event("UPDATE_LIST", [4, 5, 6]))
  #   end
  # end

  test "unhandle event" do
    assert :discard == Test.Event.Handler.handle_event(event("DISCARD", :some_event))
  end

  defp event(type, data) do
    %Brook.Event{type: type, data: data}
  end
end
