defmodule Brook.Driver.Kafka do
  @behaviour Brook.Driver
  use Supervisor
  require Logger

  alias Brook.Event.Kafka.Serializer

  @name :brook_driver_elsa

  @impl Brook.Driver
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg)
  end

  @impl Supervisor
  def init(init_arg) do
    topic = Keyword.fetch!(init_arg, :topic)

    elsa_group_config = [
      name: @name,
      endpoints: Keyword.fetch!(init_arg, :endpoints),
      group: Keyword.fetch!(init_arg, :group),
      topics: [topic],
      handler: Brook.Driver.Kafka.Handler,
      handler_init_args: [],
      config: Keyword.get(init_arg, :config, [])
    ]

    elsa_producer_config = [
      name: @name,
      endpoints: Keyword.fetch!(init_arg, :endpoints),
      topic: topic
    ]

    store_topic(topic)

    children = [
      {Elsa.Group.Supervisor, elsa_group_config},
      {Elsa.Producer.Supervisor, elsa_producer_config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @impl Brook.Driver
  def ack(%{topic: topic, partition: partition, generation_id: generation_id}, ack_data) do
    max_offset =
      ack_data
      |> Enum.map(fn ack -> ack.offset end)
      |> Enum.max()

    Elsa.Group.Manager.ack(:brook_driver_elsa, topic, partition, generation_id, max_offset)
  end

  @impl Brook.Driver
  def send_event(type, author, data) do
    case create_message(type, author, data) do
      {:ok, message} ->
        Elsa.produce_sync(get_topic(), {type, Jason.encode!(message)}, name: @name)

      {:error, reason} ->
        Logger.error(
          "Unable to send event to kafka broker: type(#{type}), author(#{author}), data(#{inspect(data)}), error reason: #{
            inspect(reason)
          }"
        )
    end
  end

  defp store_topic(topic) do
    Registry.put_meta(Brook.Registry, :"#{@name}_topic", topic)
  end

  defp get_topic() do
    {:ok, topic} = Registry.meta(Brook.Registry, :"#{@name}_topic")
    topic
  end

  defp create_message(type, author, data) do
    message = %{"type" => type, "author" => author}

    case Serializer.serialize(data) do
      {:ok, value} -> {:ok, Map.put(message, "data", value)}
      {:ok, struct, value} -> {:ok, Map.put(message, "data", value) |> Map.put("__struct__", struct)}
      result -> result
    end
  end
end
