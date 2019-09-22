defmodule Brook.Driver.KafkaTest do
  use ExUnit.Case
  use Placebo

  setup do
    allow Registry.meta(any(), any()), return: {:ok, %{name: :name, topic: :topic}}
    :ok
  end

  describe "send_event/2" do
    test "will retry several times before giving up" do
      allow Elsa.produce_sync(any(), any(), any()), seq: [{:error, "message", []}, {:error, "message", []}, :ok]

      assert :ok == Brook.Driver.Kafka.send_event(:registry, :type, :message)

      assert_called Elsa.produce_sync(:topic, {:type, :message}, any()), times(3)
    end

    test "will return the last error received" do
      allow Elsa.produce_sync(any(), any(), any()), return: {:error, "message", []}

      assert {:error, "message", []} == Brook.Driver.Kafka.send_event(:registry, :type, :message)
    end
  end
end
