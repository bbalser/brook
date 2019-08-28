require Protocol
Protocol.derive(Jason.Encoder, Brook.Event)

defimpl Brook.Serializer, for: Brook.Event do
  @moduledoc """
  Implement the `Brook.Serializer` protocol for the
  `Brook.Event` struct type.
  """

  def serialize(%Brook.Event{} = event) do
    %{"type" => event.type, "author" => event.author, "create_ts" => event.create_ts}
    |> serialize_data(event.data)
    |> add_struct(event.data)
    |> encode()
  end

  defp serialize_data(message, data) do
    case Brook.Serializer.serialize(data) do
      {:ok, value} -> {:ok, Map.put(message, "data", value)}
      error_result -> error_result
    end
  end

  defp add_struct({:ok, message}, %custom_struct{}) do
    {:ok, Map.put(message, "__struct__", custom_struct)}
  end

  defp add_struct(message, _data), do: message

  defp encode({:ok, value}), do: Jason.encode(value)
  defp encode({:error, _reason} = error), do: error
end

defimpl Brook.Deserializer, for: Brook.Event do
  @moduledoc """
  Implement the `Brook.Deserializer` protocol for the
  `Brook.Event` struct type.
  """

  def deserialize(%Brook.Event{}, data) do
    data
    |> Jason.decode(keys: :atoms)
    |> get_struct()
    |> deserialize_data()
    |> to_struct()
  end

  defp get_struct({:ok, %{__struct__: custom_struct} = data}) do
    struct_module = String.to_atom(custom_struct)
    Code.ensure_loaded(struct_module)

    case function_exported?(struct_module, :__struct__, 0) do
      true -> {:ok, struct(struct_module), Map.delete(data, :__struct__)}
      false -> {:error, :invalid_struct}
    end
  end

  defp get_struct({:ok, data}), do: {:ok, :undefined, data}
  defp get_struct({:error, _reason} = error), do: error

  defp deserialize_data({:ok, data_struct, decoded_json}) do
    case Brook.Deserializer.deserialize(data_struct, decoded_json.data) do
      {:ok, value} -> {:ok, Map.put(decoded_json, :data, value)}
      error_result -> error_result
    end
  end

  defp deserialize_data({:error, _reason} = error), do: error

  defp to_struct({:ok, value}), do: {:ok, struct(Brook.Event, value)}
  defp to_struct({:error, _reason} = error), do: error
end
