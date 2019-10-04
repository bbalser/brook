defmodule Brook.Driver.KafkaTest do
  use ExUnit.Case
  use Placebo

  setup do
    allow Registry.meta(any(), any()), return: {:ok, %{connection: :client, topic: :topic}}
    :ok
  end

  describe "send_event/2" do
    test "will retry several times before giving up" do
      allow Elsa.produce(any(), any(), any()), seq: [{:error, "message", []}, {:error, "message", []}, :ok]

      assert :ok == Brook.Driver.Kafka.send_event(:registry, :type, :message)

      assert_called Elsa.produce(:client, :topic, {:type, :message}), times(3)
    end

    test "will return the last error received" do
      allow Elsa.produce(any(), any(), any()), return: {:error, "message", []}

      assert {:error, "message", []} == Brook.Driver.Kafka.send_event(:registry, :type, :message)
    end
  end
end
