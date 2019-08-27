defmodule Brook.Event.Handler do
  @moduledoc """
  Defines the `Brook.Event.Handler` behaviour that an application
  is expected to provide for processing events off the event stream via
  Brook, as well as a default implementation.
  """

  @typedoc "The return value of a create operation to save a value to the view state"
  @type create :: {:create, Brook.view_collection(), Brook.view_key(), Brook.view_value()}

  @typedoc "The return value of a delete operation to remove a value from the view state"
  @type delete :: {:delete, Brook.view_collection(), Brook.view_key()}

  @typedoc """
  The return value of merging a new value into the existing value with the view state
  saved under a given key and collection.
  """
  @type merge :: {:merge, Brook.view_collection(), Brook.view_key(), Brook.view_value()}

  @typedoc "The return value of an event that should not persist any result to the view state."
  @type discard :: :discard

  @doc """
  Process incoming events from the event stream and return a result with optional persistence
  of values to the application view state.
  """
  @callback handle_event(Brook.Event.t()) :: create() | delete() | merge() | discard()

  @doc """
  A using macro to define a module as implementing the `Brook.Event.Handler` behaviour
  and supply a default implementation of the required `handle_event/1` function.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Brook.Event.Handler
      @before_compile Brook.Event.Handler
    end
  end

  @doc """
  Simple default `handle_event/1` implementation that discards the message and
  takes no other action.
  """
  defmacro __before_compile__(_env) do
    quote do
      def handle_event(%Brook.Event{} = _event) do
        :discard
      end
    end
  end
end
