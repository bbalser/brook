defmodule Brook.Event do
  @moduledoc """
  The `Brook.Event` struct is the basic unit of message written to
  and read from the event stream. It encodes the type of event (for
  application event handlers to pattern match on), the author (source application),
  The creation timestamp of the message, the actual data of the message,
  and a boolean detailing if the message was forwarded within the Brook
  Server process group.

  The data component of the message is an arbitrary Elixir term but is typically
  a map or struct.
  """
  require Logger

  @type data :: term()
  @type driver :: term()

  @type t :: %__MODULE__{
          type: String.t(),
          author: Brook.author(),
          create_ts: pos_integer(),
          data: data(),
          forwarded: boolean()
        }

  @enforce_keys [:type, :author, :data, :create_ts]
  defstruct type: nil,
            author: nil,
            create_ts: nil,
            data: nil,
            forwarded: false

  def new(args) do
    struct!(__MODULE__, Keyword.put_new(args, :create_ts, now()))
  end

  @doc """
  Takes a `Brook.Event` struct and a function and updates the data value of the struct
  based on the outcome of applying the function to the incoming data value. Merges the resulting
  data value back into the struct.
  """
  @spec update_data(Brook.Event.t(), (data() -> data())) :: Brook.Event.t()
  def update_data(%Brook.Event{data: data} = event, function) when is_function(function, 1) do
    %Brook.Event{event | data: function.(data)}
  end

  @doc """
  Send a message to the `Brook.Server` synchronously, passing the term to be encoded into a
  `Brook.Event` struct, the authoring application, and the type of event. The event type must
  implement the `String.Chars.t` type.
  """
  @spec send(Brook.instance(), Brook.event_type(), Brook.author(), Brook.event()) :: :ok | {:error, Brook.reason()}
  def send(instance, type, author, event) do
    send(instance, type, author, event, Brook.Config.driver(instance))
  end

  @spec send(Brook.instance(), Brook.event_type(), Brook.author(), Brook.event(), driver()) ::
          :ok | {:error, Brook.reason()}
  def send(instance, type, author, event, driver) do
    brook_event =
      Brook.Event.new(
        type: type,
        author: author,
        data: event
      )

    case Brook.Serializer.serialize(brook_event) do
      {:ok, serialized_event} ->
        :ok = apply(driver.module, :send_event, [instance, type, serialized_event])

      {:error, reason} ->
        Logger.error(
          "Unable to send event: type(#{type}), author(#{author}), event(#{inspect(event)}), error reason: #{
            inspect(reason)
          }"
        )
    end

    :ok
  end

  @doc """
  Process a `Brook.Event` struct via synchronous call to the `Brook.Server`
  """
  @spec process(Brook.instance(), Brook.Event.t() | term()) :: :ok | {:error, Brook.reason()}
  def process(instance, event) do
    registry = Brook.Config.registry(instance)
    GenServer.call({:via, Registry, {registry, Brook.Server}}, {:process, event})
  end

  defp now(), do: DateTime.utc_now() |> DateTime.to_unix(:millisecond)
end
