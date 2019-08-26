defprotocol Brook.Event.Kafka.Serializer do
  @type type :: atom()
  @type reason :: term()
  @fallback_to_any true

  @spec serialize(term()) :: {:ok, type(), term()} | {:ok, term()} | {:error, reason()}
  def serialize(data)
end

defprotocol Brook.Event.Kafka.Deserializer do
  @type t :: term()
  @type reason :: term()
  @fallback_to_any true

  @spec deserialize(t(), term()) :: {:ok, term()} | {:error, reason()}
  def deserialize(struct, data)
end

defimpl Brook.Event.Kafka.Serializer, for: Any do
  def serialize(%custom_struct{} = data) do
    case data |> Map.from_struct() |> serialize() do
      {:ok, serialized_data} -> {:ok, custom_struct, serialized_data}
      error_result -> error_result
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

  def deserialize(%struct_module{}, data) do
    case Jason.decode(data, keys: :atoms) do
      {:ok, decoded_json} -> {:ok, struct(struct_module, decoded_json)}
      error_result -> error_result
    end
  end
end
