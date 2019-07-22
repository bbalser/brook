defmodule Brook.Snapshot.Storage do
  @callback init(any()) :: {:ok, any()}

  @callback store(any(), any()) :: :ok

  @callback get_latest(any()) :: any()
end
