defmodule Brook do
  defdelegate start_link(opts), to: Brook.Supervisor

  defdelegate child_spec(args), to: Brook.Supervisor

  def process(type, event) do
    GenServer.call({:via, Registry, {Brook.Registry, Brook.Server}}, {:process, type, event})
  end

  def get(key) do
    case :ets.lookup(Brook.Server, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end
end
