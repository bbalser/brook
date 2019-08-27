defprotocol Brook.Event.Serializer do
  @moduledoc """
  The protocol for standard serialization of Elixir structs to
  an in-transit encoding format before sending on the Brook event stream.

  Brook drivers are expected to implement a default serializer for
  converting to the given encoding, leaving the client the option to
  implement a custom serializer for specific struct types.
  """
  @type type :: atom()
  @type reason :: term()
  @fallback_to_any true

  @doc """
  Convert the supplied Elixir term to an encoded term wrapped in an `:ok` tuple.
  """
  @spec serialize(term()) :: {:ok, term()} | {:error, reason()}
  def serialize(data)
end

defprotocol Brook.Event.Deserializer do
  @moduledoc """
  The protocol for standard de-serialization of Elixir structs passed
  through the Brook event stream for decoding from the in-transit format.

  Brook drivers are expected to implement a default de-serializer for
  converting from a given encoding to an Elixir struct, leaving the client
  the option to implement a custom de-serializer for specific struct types.
  """
  @type t :: term()
  @type reason :: term()
  @fallback_to_any true

  @doc """
  Convert the given encoded term to an instance of the supplied struct
  type.
  """
  @spec deserialize(t(), term()) :: {:ok, term()} | {:error, reason()}
  def deserialize(struct, data)
end
