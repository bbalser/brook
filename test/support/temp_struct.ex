defmodule TempStruct do
  @derive Jason.Encoder
  defstruct [:name, :age, :location]
end

defmodule TempModule do
  def _i_am_a_module_but_not_a_struct(), do: nil
end
