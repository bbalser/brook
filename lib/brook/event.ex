defmodule Brook.Event do
  @type data :: term()

  @type t :: %__MODULE__{
          type: String.t(),
          author: Brook.author(),
          create_ts: pos_integer(),
          data: data(),
          ack_ref: term(),
          ack_data: term(),
          forwarded: boolean()
        }

  @enforce_keys [:type, :author, :data]
  defstruct type: nil,
            author: nil,
            create_ts: nil,
            data: nil,
            ack_ref: nil,
            ack_data: nil,
            forwarded: false

  @spec update_data(Brook.Event.t(), (data() -> data())) :: Brook.Event.t()
  def update_data(%Brook.Event{data: data} = event, function) when is_function(function, 1) do
    %Brook.Event{event | data: function.(data)}
  end
end
