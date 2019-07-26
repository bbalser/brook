defmodule Brook.Snapshot do
  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback persist(list({term(), term()})) :: :ok | {:error, Brook.reason()}

  @callback delete(list()) :: :ok | {:error, Brook.reason()}

  @callback get_latest() :: term()
end
