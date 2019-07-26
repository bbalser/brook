defmodule Brook.SnapshotTest do
  use ExUnit.Case
  import Assertions

  defmodule TestSnapshot.Driver do
    @behaviour Brook.Driver
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: via())
    end

    def init(args) do
      {:ok, args}
    end

    def ack(ack_ref, ack_data) do
      GenServer.cast(via(), {:ack, ack_ref, ack_data})
    end

    def send_event(_type, _event) do
      nil
    end

    def handle_cast({:ack, ack_ref, ack_data}, state) do
      send(state.pid, {:ack, ack_ref, ack_data})
      {:noreply, state}
    end

    defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
  end

  defmodule TestSnapshot.Storage do
    @behaviour Brook.Snapshot
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: via())
    end

    def init(init_args) do
      {:ok, init_args}
    end

    def get_latest() do
      %{"key1" => "value1"}
    end

    def persist(entries) do
      GenServer.cast(via(), {:persist, entries})
    end

    def delete(keys) do
      GenServer.cast(via(), {:delete, keys})
    end

    def handle_cast({:persist, entries}, state) do
      Enum.each(entries, fn {key, value} -> send(state.pid, {:persist, key, value}) end)
      {:noreply, state}
    end

    def handle_cast({:delete, keys}, state) do
      Enum.each(keys, fn key -> send(state.pid, {:delete, key}) end)
      {:noreply, state}
    end

    defp via(), do: {:via, Registry, {Brook.Registry, __MODULE__}}
  end

  setup do
    config = [
      driver: %{
        module: TestSnapshot.Driver,
        init_arg: %{pid: self()}
      },
      handlers: [Test.Event.Handler],
      snapshot: %{
        module: TestSnapshot.Storage,
        interval: 2,
        init_arg: %{pid: self()}
      }
    ]

    {:ok, brook} = Brook.start_link(config)

    on_exit(fn ->
      ref = Process.monitor(brook)
      Process.exit(brook, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)

    [brook: brook]
  end

  test "entries are snapshotted at the interval configured" do
    Brook.process(%Brook.Event{type: "CREATE", data: %{"id" => 123, "name" => "Gary"}})

    entry = Brook.get(123)

    assert_receive {:persist, 123, ^entry}, 3_000

    Brook.process(%Brook.Event{type: "DELETE", data: %{"id" => 123, "name" => "Gary"}})

    nil = Brook.get(123)

    assert_receive {:delete, 123}, 3_000
  end

  test "entries are retrieved from latest snapshot on init" do
    assert_async(timeout: 5_000, sleep_time: 500) do
      assert "value1" == Brook.get("key1")
    end
  end

  test "messages are ack after being snapshotted" do
    messages = [
      %Brook.Event{type: "CREATE", data: %{"id" => 123, "name" => "Bobby"}, ack_ref: "A", ack_data: "Bobby"},
      %Brook.Event{type: "CREATE", data: %{"id" => 345, "name" => "Scott"}, ack_ref: "B", ack_data: "Scott"},
      %Brook.Event{type: "CREATE", data: %{"id" => 678, "name" => "Brian"}, ack_ref: "A", ack_data: "Brian"},
      %Brook.Event{type: "CREATE", data: %{"id" => 901, "name" => "Frank"}, ack_ref: "C", ack_data: "Frank"}
    ]

    Enum.each(messages, fn msg -> Brook.process(msg) end)

    assert_receive {:ack, "A", ["Bobby", "Brian"]}, 3_000
    assert_receive {:ack, "B", ["Scott"]}, 1_000
    assert_receive {:ack, "C", ["Frank"]}, 1_000
  end
end
