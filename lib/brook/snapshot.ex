defmodule Brook.Snapshot do
  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback store(term()) :: :ok | {:error, Brook.reason()}

  @callback get_latest() :: any()
end
