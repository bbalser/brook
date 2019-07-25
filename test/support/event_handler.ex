defmodule Test.Event.Handler do
  use Brook.Event.Handler

  def handle_event(%Brook.Event{type: "CREATE", data: data}) do
    {:update, data["id"], Test.Event.Data.new(data)}
  end

  def handle_event(%Brook.Event{type: "DELETE", data: data}) do
    {:delete, data["id"]}
  end
end
