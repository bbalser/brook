defmodule Brook.Event.Handler do
  @callback handle_event(atom(), any()) :: {:update, any(), any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Brook.Event.Handler
      @before_compile Brook.Event.Handler
    end
  end

  defmacro __before_compile__(env) do
    quote do
      def handle_event(_type, _event) do
        :discard
      end
    end
  end
end
