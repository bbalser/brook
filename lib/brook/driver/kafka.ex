defmodule Brook.Driver.Kafka do
  @behaviour Brook.Driver
  use Supervisor
  require Logger

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
  def send_event(type, message) do
    Elsa.produce_sync(get_topic(), {type, message}, name: @name)
  end

  defp store_topic(topic) do
    Registry.put_meta(Brook.Registry, :"#{@name}_topic", topic)
  end

  defp get_topic() do
    {:ok, topic} = Registry.meta(Brook.Registry, :"#{@name}_topic")
    topic
  end
end
