defmodule Brook.Event do
  @type data :: term()

  @type t :: %__MODULE__{
          type: String.t(),
          data: data(),
          ack_ref: term(),
          ack_data: term()
        }

  @enforce_keys [:type, :data]
  defstruct [:type, :data, :ack_ref, :ack_data]

  @spec update_data(Brook.Event.t(), (data() -> data())) :: Brook.Event.t()
  def update_data(%Brook.Event{data: data} = event, function) when is_function(function, 1) do
    %Brook.Event{event | data: function.(data)}
  end
end
