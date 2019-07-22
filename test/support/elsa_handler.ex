defmodule Test.Elsa.Handler do
  use Elsa.Consumer.MessageHandler

  def handle_messages(messages) do
    messages
    |> Enum.each(fn %{key: type, value: event} -> Brook.process(type, event) end)

    :ack
  end
end
