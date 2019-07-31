defmodule Test.Update.Handler do
  use Brook.UpdateHandler

  def handle_update(collection, key, value, state) do
    send(state.pid, {:update, collection, key, value})
    {:ok, state}
  end
end
