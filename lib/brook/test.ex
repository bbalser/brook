defmodule Brook.Test do
  import Brook.Config, only: [registry: 1]

  def register(instance) do
    GenServer.cast(Brook.Driver.Test.via(registry(instance)), {:register, self()})
  end

  @spec send(Brook.instance(), Brook.event_type(), Brook.author(), Brook.event()) :: :ok | {:error, Brook.reason()}
  def send(instance, type, author, data) do
    register(instance)
    Brook.Event.send(instance, type, author, data, %{module: Brook.Driver.Default, init_arg: []})
    :ok
  end

  def with_event(instance, function) when is_function(function, 0) do
    with_event(instance, fake_event(), function)
  end

  def with_event(instance, event, function) when is_function(function, 0) do
    register(instance)
    GenServer.call({:via, Registry, {registry(instance), Brook.Server}}, {:execute_test_function, event, function})
  end

  def clear_view_state(instance, collection) do
    storage = Brook.Config.storage(instance)

    {:ok, entries} = apply(storage.module, :get_all, [instance, collection])

    entries
    |> Enum.each(fn {key, _value} ->
      apply(storage.module, :delete, [instance, collection, key])
    end)
  end

  defp fake_event(), do: Brook.Event.new(type: "fake:test:event", author: "testing", data: :test)
end
