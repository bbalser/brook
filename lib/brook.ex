defmodule Brook do
  @type event_type :: String.t()
  @type event :: term()

  @type view_key :: String.Chars.t()
  @type view_body :: term()

  @type reason :: term()

  defdelegate start_link(opts), to: Brook.Supervisor

  defdelegate child_spec(args), to: Brook.Supervisor

  @spec send_event(event_type(), event()) :: :ok | {:error, reason()}
  def send_event(type, event) do
    nil
  end

  @spec process(event_type(), event()) :: :ok | {:error, reason()}
  def process(type, event) do
    GenServer.call({:via, Registry, {Brook.Registry, Brook.Server}}, {:process, type, event})
  end

  @spec get(view_key()) :: view_body()
  def get(key) do
    case :ets.lookup(Brook.Server, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end
end
