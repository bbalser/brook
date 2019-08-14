defmodule Brook.Config do
  @default_driver %{module: Brook.Driver.Default, init_arg: []}

  defstruct driver: nil,
            event_handlers: nil,
            storage: nil,
            dispatcher: nil

  def new(opts) do
    %__MODULE__{
      driver: Keyword.get(opts, :driver, @default_driver) |> Enum.into(%{}),
      event_handlers: Keyword.fetch!(opts, :handlers),
      storage: Keyword.fetch!(opts, :storage) |> Enum.into(%{}),
      dispatcher: Keyword.get(opts, :dispatcher, Brook.Dispatcher.Default)
    }
  end
end
