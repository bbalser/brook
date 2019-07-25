defmodule Brook.Driver do
  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback send_event(Brook.event_type(), Brook.event()) :: :ok | {:error, Brook.reason()}
end
