defmodule BrookTest do
  use ExUnit.Case
  use Placebo
  import Assertions

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
    :ok = Brook.Event.process(event("CREATE", %{"id" => 123, "name" => "George"}))

    assert_async(timeout: 1_000, sleep_time: 100) do
      assert {:ok, %{"id" => 123, "name" => "George"}} == Brook.get(:all, 123)
    end
  end

  test "calls dispatcher" do
    allow Brook.Dispatcher.Default.dispatch(any()), return: :ok
    event = event("CREATE", %{"id" => 456, "name" => "Bob"})
    :ok = Brook.Event.process(event)

    assert_called Brook.Dispatcher.Default.dispatch(event)
  end

  test "does not call storage module when forwarded is true" do
    :ok = Brook.Event.process(event("CREATE", %{"id" => 123, "name" => "Robert"}, forwarded: true))

    assert nil == Brook.get!(:all, 123)
  end

  test "delete store" do
    Brook.Event.process(event("CREATE", %{"id" => 123, "name" => "George"}))
    Brook.Event.process(event("DELETE", %{"id" => 123}))

    assert {:ok, nil} == Brook.get(:all, 123)
  end

  test "merge map into view state" do
    Brook.Event.process(event("CREATE", %{"id" => 1, "name" => "Brody", "age" => 21}))
    Brook.Event.process(event("UPDATE", %{"id" => 1, "age" => 22, "married" => true}))

    assert_async(timeout: 1_000, sleep_time: 100) do
      assert {:ok, %{"id" => 1, "name" => "Brody", "age" => 22, "married" => true}} == Brook.get(:all, 1)
    end
  end

  test "merge map into non existant state" do
    Brook.Event.process(event("UPDATE", %{"id" => 1, "name" => "Brody"}))

    assert_async(timeout: 1_000, sleep_time: 100) do
      assert {:ok, %{"id" => 1, "name" => "Brody"}} == Brook.get(:all, 1)
    end
  end

  test "merge keyword list into view state" do
    Brook.Event.process(event("CREATE", id: 1, name: "Jeff", age: 21))
    Brook.Event.process(event("UPDATE", id: 1, age: 22, married: true))

    assert_async(timeout: 1_000, sleep_time: 100) do
      {:ok, actual} = Brook.get(:all, 1)
      assert keyword_equals([id: 1, name: "Jeff", age: 22, married: true], actual)
    end
  end

  test "merge keyword list into not existent state" do
    Brook.Event.process(event("UPDATE", id: 1, age: 22, married: true))

    assert_async(timeout: 1_000, sleep_time: 100) do
      {:ok, actual} = Brook.get(:all, 1)
      assert keyword_equals([id: 1, age: 22, married: true], actual)
    end
  end

  test "merge using function into view state" do
    Brook.Event.process(event("CREATE", %{"id" => 1, "total" => 10}))
    Brook.Event.process(event("ADD", %{"id" => 1, "add" => 5}))

    assert_async(timeout: 1_000, sleep_time: 100) do
      {:ok, actual} = Brook.get(:all, 1)
      assert %{"id" => 1, "total" => 15} == actual
    end
  end

  test "get_all returns all events" do
    Brook.Event.process(event("CREATE", %{"id" => 1, "total" => 10}))
    Brook.Event.process(event("CREATE", %{"id" => 2, "total" => 10}))

    expected = %{
      1 => %{"id" => 1, "total" => 10},
      2 => %{"id" => 2, "total" => 10}
    }

    assert_async(timeout: 1_000, sleep_time: 100) do
      assert {:ok, expected} == Brook.get_all(:all)
    end
  end

  test "unhandle event" do
    assert :discard == Test.Event.Handler.handle_event(event("DISCARD", :some_event))
  end

  defp event(type, data, opts \\ []) do
    %Brook.Event{type: type, author: "testing", data: data}
    |> Map.merge(Enum.into(opts, %{}))
  end

  defp keyword_equals(left, right) when is_nil(left) or is_nil(right) do
    false
  end

  defp keyword_equals(left, right) do
    Keyword.equal?(left, right)
  end
end
