defmodule Brook.Event.Handler do
  @callback handle_event(Brook.Event.t()) :: {:update, any(), any()} | {:delete, any()} | :discard

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
