defmodule Brook.Dispatcher do

  @callback init() :: :ok

  @callback dispatch(Brook.Event.t()) :: :ok
end

defmodule Brook.Dispatcher.Default do
  @behaviour Brook.Dispatcher

  @group :brook_servers

  def init() do
    :pg2.create(@group)
    [{pid, _}] = Registry.lookup(Brook.Registry, Brook.Server)
    :pg2.join(@group, pid)
  end

  def dispatch(%Brook.Event{} = event) do
    forwarded_event = %{event | forwarded: true}

    :pg2.get_members(@group) -- :pg2.get_local_members(@group)
    |> Enum.each(fn pid ->
      GenServer.cast(pid, {:process, forwarded_event})
    end)
  end
end
