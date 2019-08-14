defmodule Brook.Dispatcher do
  @callback dispatch(Brook.Event.t()) :: :ok
end

defmodule Brook.Dispatcher.Default do
  @behaviour Brook.Dispatcher

  def dispatch(%Brook.Event{} = event) do
    case Node.list() do
      [] ->
        :ok

      nodes ->
        forwarded_event = %{event | forwarded: true}

        Enum.each(nodes, fn node ->
          via = {:via, Registry, {Brook.Registry, Brook.Server}}
          :rpc.call(node, GenServer, :cast, [via, {:process, forwarded_event}])
        end)
    end
  end
end
