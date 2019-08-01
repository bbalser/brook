defmodule Brook do
  @type event_type :: String.t()
  @type event :: term()

  @type view_collection :: String.Chard.t()
  @type view_key :: String.Chars.t()
  @type view_value :: term()

  @type reason :: term()

  defmodule UnsupportedMerge do
    defexception [:message]
  end

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

  @spec get(view_collection(), view_key()) :: view_value()
  defdelegate get(collection, key), to: Brook.Server

  @spec get_events(view_collection(), view_key()) :: list(Brook.Event.t())
  defdelegate get_events(collection, key), to: Brook.Server

  @spec get_all(view_collection()) :: %{required(view_key()) => view_value()}
  defdelegate get_all(collection), to: Brook.Server
end
