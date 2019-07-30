defmodule Brook.Config do
  @default_driver %{module: Brook.Driver.Default, init_arg: []}

  defstruct driver: nil,
            event_handlers: nil,
            watches: nil,
            storage: nil

  def new(opts) do
    %__MODULE__{
      driver: Keyword.get(opts, :driver, @default_driver) |> Enum.into(%{}),
      event_handlers: Keyword.fetch!(opts, :handlers),
      watches: Keyword.get(opts, :watches, %{}) |> Enum.into(%{}),
      storage: Keyword.fetch!(opts, :storage) |> Enum.into(%{})
    }
  end
end
