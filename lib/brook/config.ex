defmodule Brook.Config do
  @default_decoder Brook.Decoder.Noop
  @default_generator Brook.Generator.Default

  defstruct [
    :elsa,
    :kafka_config,
    :generator,
    :generator_config,
    :decoder,
    :event_handlers,
    :snapshot,
    :snapshot_state,
    :snapshot_timer
  ]

  def new(opts) do
    %__MODULE__{
      generator: Keyword.get(opts, :generator, @default_generator),
      generator_config: Keyword.get(opts, :generator_config, %{}),
      decoder: Keyword.get(opts, :decoder, @default_decoder),
      event_handlers: Keyword.fetch!(opts, :handlers),
      snapshot: Keyword.get(opts, :snapshot, %{})
    }
  end
end
