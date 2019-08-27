defmodule TempStruct do
  @derive Jason.Encoder
  defstruct [:name, :age, :location]
end
