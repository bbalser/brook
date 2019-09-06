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
end
