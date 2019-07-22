defmodule Test.Event.Handler do
  use Brook.Event.Handler

  @events ["CREATE", "DELETE"]

  def handle_event("CREATE", event) do
    {:update, event["id"], Test.Event.Data.new(event)}
  end

  def handle_event("DELETE", event) do
    {:delete, event["id"]}
  end
end
