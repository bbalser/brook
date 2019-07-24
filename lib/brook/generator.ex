defmodule Brook.Generator do
  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback create_event(Brook.event_type(), Brook.event()) :: :ok | {:error, Brook.reason()}
end
