defmodule Brook.Config do
  @default_decoder Brook.Decoder.Noop
  @default_generator %{module: Brook.Generator.Default, init_arg: []}

  defstruct [
    :elsa,
    :kafka_config,
    :generator,
    :decoder,
    :event_handlers,
    :snapshot,
    :snapshot_timer
  ]

  def new(opts) do
    %__MODULE__{
      generator: Keyword.get(opts, :generator, @default_generator),
      decoder: Keyword.get(opts, :decoder, @default_decoder),
      event_handlers: Keyword.fetch!(opts, :handlers),
      snapshot: Keyword.get(opts, :snapshot, %{})
    }
  end
end
