defmodule Brook.Test do

  def register() do
    GenServer.cast(Brook.Driver.Test.via(), {:register, self()})
  end

  @spec send(Brook.event_type(), Brook.author(), Brook.event()) :: :ok | {:error, Brook.reason()}
  def send(type, author, data) do
    register()
    Brook.Event.send(type, author, data, %{module: Brook.Driver.Default, init_arg: []})
    :ok
  end

  def save_view_state(event, collection, key, value) do
    storage = Brook.Config.storage()
    apply(storage.module, :persist, [event, collection, key, value])
  end

  def save_view_state(collection, key, value) do
    event = %Brook.Event{type: "fake:test:event", author: "testing", data: nil}
    save_view_state(event, collection, key, value)
  end

  def clear_view_state(collection) do
    storage = Brook.Config.storage()
    apply(storage.module, :get_all, [collection])
    |> Enum.each(fn {key, _value} ->
      apply(storage.module, :delete, [collection, key])
    end)
  end
end
