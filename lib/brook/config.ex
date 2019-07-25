defmodule Brook.Config do
  @default_decoder Brook.Decoder.Noop
  @default_driver %{module: Brook.Driver.Default, init_arg: []}

  defstruct [
    :elsa,
    :kafka_config,
    :driver,
    :decoder,
    :event_handlers,
    :snapshot,
    :snapshot_timer
  ]

  def new(opts) do
    %__MODULE__{
      driver: Keyword.get(opts, :driver, @default_driver),
      decoder: Keyword.get(opts, :decoder, @default_decoder),
      event_handlers: Keyword.fetch!(opts, :handlers),
      snapshot: Keyword.get(opts, :snapshot, %{})
    }
  end
end
