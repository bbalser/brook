defmodule Brook.UpdateHandler do
  @callback init(term()) :: {:ok, term()}

  @callback handle_update(Brook.view_key(), Brook.view_body(), term()) :: {:ok, term()}

  @callback handle_update(Brook.view_key(), Brook.view_body()) :: :ok

  @optional_callbacks handle_update: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Brook.UpdateHandler

      def init(arg) do
        {:ok, arg}
      end

      def handle_update(key, value, state) do
        :ok = handle_update(key, value)
        {:ok, state}
      end

      defoverridable Brook.UpdateHandler
    end
  end
end
