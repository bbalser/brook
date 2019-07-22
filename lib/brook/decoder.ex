defmodule Brook.Decoder do
  @callback decode(any()) :: any()
end
