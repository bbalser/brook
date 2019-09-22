require Protocol
Protocol.derive(Jason.Encoder, Brook.Event)

defimpl Brook.Serializer.Protocol, for: Brook.Event do
  @moduledoc """
  Implement the `Brook.Serializer` protocol for the
  `Brook.Event` struct type.
  """

  @struct_key "__brook_struct__"

  def serialize(%Brook.Event{} = event) do
    %{"type" => event.type, "author" => event.author, "create_ts" => event.create_ts, "forwarded" => event.forwarded}
    |> Map.put(@struct_key, Brook.Event)
    |> serialize_data(event.data)
    |> encode()
  end

  defp serialize_data(message, data) do
    case Brook.Serializer.serialize(data) do
      {:ok, value} -> {:ok, Map.put(message, "data", value)}
      error_result -> error_result
    end
  end

  defp encode({:ok, value}), do: Jason.encode(value)
  defp encode({:error, _reason} = error), do: error
end

defimpl Brook.Deserializer.Protocol, for: Brook.Event do
  @moduledoc """
  Implement the `Brook.Deserializer` protocol for the
  `Brook.Event` struct type.
  """

  def deserialize(%Brook.Event{}, data) do
    data
    |> deserialize_data()
    |> to_struct()
  end

  defp deserialize_data(decoded_json) do
    case Brook.Deserializer.deserialize(decoded_json.data) do
      {:ok, value} -> {:ok, Map.put(decoded_json, :data, value)}
      error_result -> error_result
    end
  end

  defp to_struct({:ok, value}), do: {:ok, struct(Brook.Event, value)}
  defp to_struct({:error, _reason} = error), do: error
end
