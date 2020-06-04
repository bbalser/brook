defmodule Brook.Serde do
  defdelegate serialize(term), to: Brook.Serializer

  defdelegate deserialize(term), to: Brook.Deserializer
end
