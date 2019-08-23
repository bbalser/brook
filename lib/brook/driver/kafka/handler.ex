defmodule Brook.Driver.Kafka.Handler do
  use Elsa.Consumer.MessageHandler
  require Logger

  alias Brook.Event.Kafka.Deserializer

  def handle_messages(messages) do
    messages
    |> Enum.map(&event/1)
    |> Enum.each(&process/1)

    :ack
  end

  defp process({:ok, %Brook.Event{} = event}) do
    Brook.Event.process(event)
  end

  defp process({:error, reason}) do
    Logger.error(reason)
  end

  defp event(%{key: type, value: value, timestamp: ts} = message) do
    decoded_json = Jason.decode!(value)

    case deserialize_data(decoded_json) do
      {:ok, data} ->
        {:ok, %Brook.Event{
          type: type,
          author: decoded_json["author"],
          create_ts: ts,
          data: data,
          ack_ref: ack_ref(message),
          ack_data: ack_data(message)
        }}

      {:error, reason} ->
        {:error, "Unable to decode event: #{inspect(message)}, error reason: #{inspect(reason)}"}
    end
  end

  defp ack_ref(%{topic: topic, partition: partition, generation_id: generation_id}) do
    %{topic: topic, partition: partition, generation_id: generation_id}
  end

  defp ack_data(%{offset: offset}) do
    %{offset: offset}
  end

  defp deserialize_data(%{"data" => data} = decoded_json) do
    decoded_json
    |> Map.get("__struct__", "undefined")
    |> String.to_atom()
    |> Deserializer.deserialize(data)
  end
end
