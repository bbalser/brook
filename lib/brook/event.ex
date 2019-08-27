defmodule Brook.Event do
  @type data :: term()

  @type t :: %__MODULE__{
          type: String.t(),
          author: Brook.author(),
          create_ts: pos_integer(),
          data: data(),
          forwarded: boolean()
        }

  @enforce_keys [:type, :author, :data]
  defstruct type: nil,
            author: nil,
            create_ts: DateTime.utc_now() |> DateTime.to_unix(:millisecond),
            data: nil,
            forwarded: false

  @spec update_data(Brook.Event.t(), (data() -> data())) :: Brook.Event.t()
  def update_data(%Brook.Event{data: data} = event, function) when is_function(function, 1) do
    %Brook.Event{event | data: function.(data)}
  end

  @spec send(Brook.event_type(), Brook.author(), Brook.event()) :: :ok | {:error, Brook.reason()}
  def send(type, author, event) do
    GenServer.call({:via, Registry, {Brook.Registry, Brook.Server}}, {:send, type, author, event})
    :ok
  end

  @spec process(Brook.Event.t() | term()) :: :ok | {:error, Brook.reason()}
  def process(event) do
    GenServer.call({:via, Registry, {Brook.Registry, Brook.Server}}, {:process, event})
  end
end
