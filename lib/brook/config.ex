defmodule Brook.Config do
  @default_decoder Brook.Decoder.Noop
  @default_driver %{module: Brook.Driver.Default, init_arg: []}

  defstruct elsa: nil,
            kafka_config: nil,
            driver: nil,
            decoder: nil,
            event_handlers: nil,
            snapshot: nil,
            snapshot_timer: nil,
            unacked: []

  def new(opts) do
    %__MODULE__{
      driver: Keyword.get(opts, :driver, @default_driver),
      decoder: Keyword.get(opts, :decoder, @default_decoder),
      event_handlers: Keyword.fetch!(opts, :handlers),
      snapshot: Keyword.get(opts, :snapshot, %{})
    }
  end
end
