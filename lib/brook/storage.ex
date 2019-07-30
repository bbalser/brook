defmodule Brook.Storage do
  @type key :: String.Chars.t()
  @type value :: term()

  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback persist(Brook.Event.t(), key(), value()) :: :ok | {:error, Brook.reason()}

  @callback delete(key()) :: :ok | {:error, Brook.reason()}

  @callback get(key()) :: value()

  @callback get_events(key()) :: list(Brook.Event.t())
end
