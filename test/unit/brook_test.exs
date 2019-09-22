defmodule BrookTest do
  use ExUnit.Case
  use Placebo
  import Assertions

  @instance :brook_test

  setup do
    {:ok, brook} =
      Brook.start_link(
        instance: @instance,
        handlers: [Test.Event.Handler]
      )

    on_exit(fn ->
      ref = Process.monitor(brook)
      Process.exit(brook, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)

    [brook: brook]
  end

  test "create entry in store" do
    :ok = Brook.Event.process(@instance, event("CREATE", %{"id" => 123, "name" => "George"}))

    assert_async do
      assert {:ok, %{"id" => 123, "name" => "George"}} == Brook.get(@instance, :all, 123)
    end
  end

  test "calls dispatcher" do
    allow Brook.Dispatcher.Default.dispatch(any(), any()), return: :ok
    event = event("CREATE", %{"id" => 456, "name" => "Bob"})
    :ok = Brook.Event.process(@instance, event)

    assert_async do
      assert_called Brook.Dispatcher.Default.dispatch(@instance, event)
    end
  end

  test "does not call storage module when forwarded is true" do
    :ok = Brook.Event.process(@instance, event("CREATE", %{"id" => 123, "name" => "Robert"}, forwarded: true))

    assert nil == Brook.get!(@instance, :all, 123)
  end

  test "delete store" do
    Brook.Event.process(@instance, event("CREATE", %{"id" => 123, "name" => "George"}))
    Brook.Event.process(@instance, event("DELETE", %{"id" => 123}))

    assert_async do
      assert {:ok, nil} == Brook.get(@instance, :all, 123)
    end
  end

  test "merge map into view state" do
    Brook.Event.process(@instance, event("CREATE", %{"id" => 1, "name" => "Brody", "age" => 21}))
    Brook.Event.process(@instance, event("UPDATE", %{"id" => 1, "age" => 22, "married" => true}))

    assert_async(timeout: 1_000, sleep_time: 100) do
      assert {:ok, %{"id" => 1, "name" => "Brody", "age" => 22, "married" => true}} == Brook.get(@instance, :all, 1)
    end
  end

  test "merge map into non existant state" do
    Brook.Event.process(@instance, event("UPDATE", %{"id" => 1, "name" => "Brody"}))

    assert_async(timeout: 1_000, sleep_time: 100) do
      assert {:ok, %{"id" => 1, "name" => "Brody"}} == Brook.get(@instance, :all, 1)
    end
  end

  test "merge keyword list into view state" do
    Brook.Event.process(@instance, event("CREATE", id: 1, name: "Jeff", age: 21))
    Brook.Event.process(@instance, event("UPDATE", id: 1, age: 22, married: true))

    assert_async do
      {:ok, actual} = Brook.get(@instance, :all, 1)
      assert keyword_equals([id: 1, name: "Jeff", age: 22, married: true], actual)
    end
  end

  test "merge keyword list into not existent state" do
    Brook.Event.process(@instance, event("UPDATE", id: 1, age: 22, married: true))

    assert_async do
      {:ok, actual} = Brook.get(@instance, :all, 1)
      assert keyword_equals([id: 1, age: 22, married: true], actual)
    end
  end

  test "merge using function into view state" do
    Brook.Event.process(@instance, event("CREATE", %{"id" => 1, "total" => 10}))
    Brook.Event.process(@instance, event("ADD", %{"id" => 1, "add" => 5}))

    assert_async do
      {:ok, actual} = Brook.get(@instance, :all, 1)
      assert %{"id" => 1, "total" => 15} == actual
    end
  end

  test "get_all returns all events" do
    Brook.Event.process(@instance, event("CREATE", %{"id" => 1, "total" => 10}))
    Brook.Event.process(@instance, event("CREATE", %{"id" => 2, "total" => 10}))

    expected = %{
      1 => %{"id" => 1, "total" => 10},
      2 => %{"id" => 2, "total" => 10}
    }

    assert_async(timeout: 1_000, sleep_time: 100) do
      assert {:ok, expected} == Brook.get_all(@instance, :all)
    end
  end

  test "unhandle event" do
    assert :discard == Test.Event.Handler.handle_event(event("DISCARD", :some_event))
  end

  defp event(type, data, opts \\ []) do
    Brook.Event.new(type: type, author: "testing", data: data)
    |> Map.merge(Enum.into(opts, %{}))
  end

  defp keyword_equals(left, right) when is_nil(left) or is_nil(right) do
    false
  end

  defp keyword_equals(left, right) do
    Keyword.equal?(left, right)
  end
end
