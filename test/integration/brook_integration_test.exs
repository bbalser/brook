defmodule Brook.IntegrationTest do
  use ExUnit.Case
  use Divo
  import Assertions

  setup do
    {:ok, redix} = Redix.start_link(host: "localhost")

    on_exit(fn ->
      kill_and_wait(redix)
    end)

    [redix: redix]
  end

  test "brook happy path", %{redix: redix} do
    config = [
      generator: %{
        module: Elsa.Group.Supervisor,
        init_arg: [
          name: :brook_elsa,
          endpoints: [localhost: 9092],
          topics: ["test"],
          group: "test-group",
          handler: Test.Elsa.Handler,
          config: [
            begin_offset: :earliest
          ]
        ]
      },
      decoder: Brook.Decoder.Json,
      handlers: [Test.Event.Handler],
      snapshot: %{
        module: Brook.Snapshot.Redis,
        interval: 10,
        init_arg: [redix_args: [host: "localhost"], namespace: "test:snapshot"]
      }
    ]

    {:ok, brook} = Brook.start_link(config)

    Elsa.produce([localhost: 9092], "test", {"CREATE", Jason.encode!(%{"id" => 123, "name" => "George"})}, partition: 0)

    assert_async(timeout: 15_000, sleep_time: 1_000) do
      assert %Test.Event.Data{id: 123, name: "George", started: false} == Brook.get(123)
      stored_snapshot = Redix.command!(redix, ["GET", "test:snapshot:123"])

      assert stored_snapshot != nil
      stored_snapshot = :erlang.binary_to_term(stored_snapshot)

      assert 123 == stored_snapshot.key
      assert %Test.Event.Data{id: 123, name: "George", started: false} == stored_snapshot.value
    end
  end

  defp kill_and_wait(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
