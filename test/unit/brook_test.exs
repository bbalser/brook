defmodule BrookTest do
  use ExUnit.Case
  use Placebo

  setup do
    {:ok, brook} =
      Brook.start_link(
        handlers: [Test.Event.Handler],
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

  test "create entry in store" do
    :ok = Brook.process(event("CREATE", %{"id" => 123, "name" => "George"}))

    assert {:ok, %{"id" => 123, "name" => "George"}} == Brook.get(:all, 123)
  end

  test "calls dispatcher" do
    allow Brook.Dispatcher.Default.dispatch(any()), return: :ok
    event = event("CREATE", %{"id" => 456, "name" => "Bob"})
    :ok = Brook.process(event)

    assert_called Brook.Dispatcher.Default.dispatch(event)
  end

  test "does not call storage module when forwrded is true" do
    :ok = Brook.process(event("CREATE", %{"id" => 123, "name" => "Robert"}, forwarded: true))

    assert nil == Brook.get!(:all, 123)
  end

  test "delete store" do
    Brook.process(event("CREATE", %{"id" => 123, "name" => "George"}))
    Brook.process(event("DELETE", %{"id" => 123}))

    assert {:ok, nil} == Brook.get(:all, 123)
  end

  test "merge map into view state" do
    Brook.process(event("CREATE", %{"id" => 1, "name" => "Brody", "age" => 21}))
    Brook.process(event("UPDATE", %{"id" => 1, "age" => 22, "married" => true}))

    assert {:ok, %{"id" => 1, "name" => "Brody", "age" => 22, "married" => true}} == Brook.get(:all, 1)
  end

  test "merge map into non existant state" do
    Brook.process(event("UPDATE", %{"id" => 1, "name" => "Brody"}))

    assert {:ok, %{"id" => 1, "name" => "Brody"}} == Brook.get(:all, 1)
  end

  test "merge keyword list into view state" do
    Brook.process(event("CREATE", id: 1, name: "Jeff", age: 21))
    Brook.process(event("UPDATE", id: 1, age: 22, married: true))

    {:ok, actual} = Brook.get(:all, 1)
    assert Keyword.equal?([id: 1, name: "Jeff", age: 22, married: true], actual)
  end

  test "merge keyword list into not existent state" do
    Brook.process(event("UPDATE", id: 1, age: 22, married: true))

    {:ok, actual} = Brook.get(:all, 1)
    assert Keyword.equal?([id: 1, age: 22, married: true], actual)
  end

  test "merge using function into view state" do
    Brook.process(event("CREATE", %{"id" => 1, "total" => 10}))
    Brook.process(event("ADD", %{"id" => 1, "add" => 5}))

    {:ok, actual} = Brook.get(:all, 1)
    assert %{"id" => 1, "total" => 15} == actual
  end

  test "get_all returns all events" do
    Brook.process(event("CREATE", %{"id" => 1, "total" => 10}))
    Brook.process(event("CREATE", %{"id" => 2, "total" => 10}))

    expected = %{
      1 => %{"id" => 1, "total" => 10},
      2 => %{"id" => 2, "total" => 10}
    }

    {:ok, actual} = Brook.get_all(:all)
    assert expected == actual
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

  defp event(type, data, opts \\ []) do
    %Brook.Event{type: type, author: "testing", data: data}
    |> Map.merge(Enum.into(opts, %{}))
  end
end
