defmodule Brook.Driver.Kafka do
  @moduledoc """
  Implements the `Brook.Driver` behaviour for using Kafka
  as the message bus underlying the event stream.

  Brook's Kafka driver uses the (Elsa)[https://github.com/bbalser/elsa]
  library for subscribing to and sending messages to a Kafka
  topic handling event stream communication between distributed
  applications.
  """
  @behaviour Brook.Driver
  use Supervisor
  require Logger

  @name :brook_driver_elsa

  @doc """
  Start `Brook.Driver` and link to the current process
  """
  @impl Brook.Driver
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg)
  end

  @doc """
  Initialize the Elsa supervision tree for the
  consumer of the event stream topic.
  """
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

  @doc """
  Send Brook event messages to the event stream topic.
  """
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
