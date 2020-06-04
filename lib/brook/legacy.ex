defmodule Brook.Legacy do
  defdelegate serialize(term), to: JsonSerde

  def deserialize(string) do
    case String.contains?(string, "__brook_struct__") do
      true -> Brook.Serde.deserialize(string)
      false -> JsonSerde.deserialize(string)
    end
  end
end
