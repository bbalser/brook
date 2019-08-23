defprotocol Brook.Event.Kafka.Serializer do
  @type type :: atom()
  @type reason :: term()
  @fallback_to_any true

  @spec serialize(term()) :: {:ok, type(), term()} | {:ok, term()} | {:error, reason()}
  def serialize(data)
end

defprotocol Brook.Event.Kafka.Deserializer do
  @type reason :: term()
  @fallback_to_any true

  @spec deserialize(module(), term()) :: {:ok, term()} | {:error, reason()}
  def deserialize(struct, data)
end

defimpl Brook.Event.Kafka.Serializer, for: Any do
  def serialize(%custom_struct{} = data) do
    case data |> Map.from_struct() |> serialize() do
      {:ok, serialized_data} -> {:ok, custom_struct, serialized_data}
      result -> result
    end
  end

  def serialize(data) do
    Jason.encode(data)
  end
end

defimpl Brook.Event.Kafka.Deserializer, for: Any do
  def deserialize(:undefined, data) do
    Jason.decode(data)
  end

  def deserialize(struct_module, data) do
    case function_exported?(struct_module, :__struct__, 0) do
      true -> decode_struct(struct_module, data)
      false -> {:error, :invalid_struct}
    end
  end

  defp decode_struct(struct_module, json) do
    case Jason.decode(json, keys: :atoms) do
      {:ok, decoded_json} -> {:ok, struct(struct_module, decoded_json)}
      result -> result
    end
  end
end
