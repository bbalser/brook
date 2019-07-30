defmodule Brook.UpdateHandler do
  @callback handle_update(Brook.view_key(), Brook.view_body()) :: :ok
end
