defmodule Test.Event.Handler do
  use Brook.Event.Handler

  def handle_event(%Brook.Event{type: "CREATE", data: data}) do
    {:create, get_id(data), data}
  end

  def handle_event(%Brook.Event{type: "DELETE", data: data}) do
    {:delete, get_id(data)}
  end

  def handle_event(%Brook.Event{type: "UPDATE", data: data}) do
    {:merge, get_id(data), data}
  end

  def handle_event(%Brook.Event{type: "ADD", data: data}) do
    {:merge, get_id(data),
     fn old ->
       Map.put(old, "total", old["total"] + data["add"])
     end}
  end

  def handle_event(%Brook.Event{type: "STORE_LIST", data: data}) do
    {:create, :list, data}
  end

  def handle_event(%Brook.Event{type: "UPDATE_LIST", data: data}) do
    {:merge, :list, data}
  end

  defp get_id(%{} = data), do: data["id"]

  defp get_id(data) when is_list(data) do
    Keyword.get(data, :id)
  end
end
