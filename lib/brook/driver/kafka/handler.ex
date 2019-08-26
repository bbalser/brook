defmodule Brook.Driver.Kafka.Handler do
  use Elsa.Consumer.MessageHandler

  def handle_messages(messages) do
    messages
    |> Enum.map(fn message -> message.value end)
    |> Enum.each(&Brook.Event.process/1)

    :ack
  end

end
