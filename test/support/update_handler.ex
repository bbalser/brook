defmodule Test.Update.Handler do
  use Brook.UpdateHandler

  def handle_update(key, value, state) do
    send(state.pid, {:update, key, value})
    {:ok, state}
  end
end
