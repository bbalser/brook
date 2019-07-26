defmodule Brook.Config do
  @default_driver %{module: Brook.Driver.Default, init_arg: []}

  defstruct driver: nil,
            event_handlers: nil,
            snapshot: nil,
            snapshot_timer: nil,
            unacked: []

  def new(opts) do
    %__MODULE__{
      driver: Keyword.get(opts, :driver, @default_driver),
      event_handlers: Keyword.fetch!(opts, :handlers),
      snapshot: Keyword.get(opts, :snapshot, %{})
    }
  end
end
