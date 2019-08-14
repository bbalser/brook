defmodule Brook.Driver do
  @type ack_ref :: term()
  @type ack_data :: term()

  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback ack(ack_ref(), list(ack_data())) :: :ok

  @callback send_event(Brook.event_type(), Brook.author(), Brook.event()) :: :ok | {:error, Brook.reason()}
end
