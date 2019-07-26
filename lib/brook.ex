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
    GenServer.call({:via, Registry, {Brook.Registry, Brook.Server}}, {:send, type, event})
    :ok
  end

  @spec process(Brook.Event.t()) :: :ok | {:error, reason()}
  def process(%Brook.Event{} = event) do
    GenServer.call({:via, Registry, {Brook.Registry, Brook.Server}}, {:process, event})
  end

  @spec get(view_key()) :: view_body()
  defdelegate get(key), to: Brook.Server
end
