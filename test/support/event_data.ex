defmodule Test.Event.Data do
  defstruct [:id, :name, :started]

  @defaults %{started: false}

  def new(opts) do
    opts =
      opts
      |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
      |> Enum.into(%{})

    @defaults
    |> Map.merge(opts)
    |> (fn x -> struct(__MODULE__, x) end).()
  end
end
