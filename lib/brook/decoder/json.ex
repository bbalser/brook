defmodule Brook.Decoder.Json do
  @behaviour Brook.Decoder

  def decode(json) do
    Jason.decode!(json)
  end
end
