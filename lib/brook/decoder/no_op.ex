defmodule Brook.Decoder.Noop do
  @behaviour Brook.Decoder

  def decode(event) do
    event
  end
end
