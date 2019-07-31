defmodule Brook.Event.Handler do
  @type create :: {:create, Brook.view_collection(), Brook.view_key(), Brook.view_value()}
  @type delete :: {:delete, Brook.view_collection(), Brook.view_key()}
  @type merge :: {:merge, Brook.view_collection(), Brook.view_key(), Brook.view_value()}
  @type discard :: :discard

  @callback handle_event(Brook.Event.t()) :: create() | delete() | merge() | discard()

  defmacro __using__(_opts) do
    quote do
      @behaviour Brook.Event.Handler
      @before_compile Brook.Event.Handler
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def handle_event(%Brook.Event{} = _event) do
        :discard
      end
    end
  end
end
