defmodule Brook.Driver.Test do
  @moduledoc """
  A driver for use in unit tests that will send any events sent by your application to your test process as messages in the format `{:brook_event, %Brook.Event{} = event}`

  Example:
  ```
  instance_name = :my_instance
  Brook.Test.register(instance_name)
  ...
  Brook.Test.send(instance_name, ...)
  ...
  assert_receive {:brook_event, %Brook.Event{...}}
  ```
  """

  @behaviour Brook.Driver
  use GenServer
  require Logger

  import Brook.Config, only: [registry: 1]

  def send_event(instance, _type, event) do
    GenServer.call(via(registry(instance)), {:send, event})
  end

  def start_link(opts) do
    instance = Keyword.fetch!(opts, :instance)
    GenServer.start_link(__MODULE__, [], name: via(registry(instance)))
  end

  def init(_args) do
    {:ok, %{}}
  end

  def handle_cast({:register, pid}, state) do
    {:noreply, Map.put(state, :pid, pid)}
  end

  def handle_call({:send, event}, _from, %{pid: pid} = state) do
    case Brook.Deserializer.deserialize(event) do
      {:ok, brook_event} ->
        send(pid, {:brook_event, brook_event})

      {:error, reason} ->
        Logger.error("Unable to deserialize event: #{inspect(event)}, error reason: #{inspect(reason)}")
    end

    {:reply, :ok, state}
  end

  def handle_call({:send, _event}, _from, state) do
    Logger.error("#{__MODULE__}: No pid available to send brook event to. Brook.Test.register/1 must be called first.")
    {:stop, :no_pid, state}
  end

  def handle_call(message, _from, state) do
    Logger.error("#{__MODULE__}: invalid message #{inspect(message)} with state #{inspect(state)}")
    {:stop, :invalid_call, state}
  end

  def via(registry) do
    {:via, Registry, {registry, __MODULE__}}
  end
end
