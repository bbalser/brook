defmodule Brook.Generator do
  @callback start_link(any()) :: GenServer.on_start()

  @callback child_spec(any()) :: Supervisor.child_spec()
end
