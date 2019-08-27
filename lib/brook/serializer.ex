defprotocol Brook.Event.Serializer do
  @type type :: atom()
  @type reason :: term()
  @fallback_to_any true

  @spec serialize(term()) ::  {:ok, term()} | {:error, reason()}
  def serialize(data)
end

defprotocol Brook.Event.Deserializer do
  @type t :: term()
  @type reason :: term()
  @fallback_to_any true

  @spec deserialize(t(), term()) :: {:ok, term()} | {:error, reason()}
  def deserialize(struct, data)
end
