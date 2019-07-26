defmodule Brook.Driver.Kafka.Handler do
  use Elsa.Consumer.MessageHandler

  def handle_messages(messages) do
    messages
    |> Enum.each(fn message -> Brook.process(event(message)) end)

    :ack
  end

  def event(%{key: type, value: data} = message) do
    %Brook.Event{
      type: type,
      data: Jason.decode!(data),
      ack_ref: ack_ref(message),
      ack_data: ack_data(message)
    }
  end

  defp ack_ref(%{topic: topic, partition: partition, generation_id: generation_id}) do
    %{topic: topic, partition: partition, generation_id: generation_id}
  end

  defp ack_data(%{offset: offset}) do
    %{offset: offset}
  end
end
