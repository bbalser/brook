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
  import Brook.Config, only: [registry: 1, get: 2, put: 3]

  @send_retry_wait 100
  @send_retry_tries 10

  @doc """
  Start `Brook.Driver` and link to the current process
  """
  @impl Brook.Driver
  def start_link(args) do
    instance = Keyword.fetch!(args, :instance)
    Supervisor.start_link(__MODULE__, args, name: via(registry(instance)))
  end

  @doc """
  Initialize the Elsa supervision tree for the
  consumer of the event stream topic.
  """
  @impl Supervisor
  def init(init_arg) do
    instance = Keyword.fetch!(init_arg, :instance)
    connection = :"brook_driver_kafka_#{instance}"
    topic = Keyword.fetch!(init_arg, :topic)

    elsa_config = [
      endpoints: Keyword.fetch!(init_arg, :endpoints),
      connection: connection,
      producer: [
        topic: topic,
        config: Keyword.get(init_arg, :producer_config, [])
      ],
      group_consumer: [
        group: Keyword.fetch!(init_arg, :group),
        topics: [topic],
        handler: Brook.Driver.Kafka.Handler,
        handler_init_args: %{instance: instance},
        config: Keyword.get(init_arg, :consumer_config, [])
      ]
    ]

    put(instance, __MODULE__, %{connection: connection, topic: topic})

    children = [
      {Elsa.Supervisor, elsa_config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Send Brook event messages to the event stream topic.
  """
  @impl Brook.Driver
  def send_event(instance, type, message) do
    send_event(instance, type, message, @send_retry_tries)
  end

  defp send_event(instance, type, message, 1) do
    produce_to_kafka(instance, type, message)
  end

  defp send_event(instance, type, message, retries) do
    case produce_to_kafka(instance, type, message) do
      {:error, _message, _non_sent} ->
        Process.sleep(@send_retry_wait)
        send_event(instance, type, message, retries - 1)

      result ->
        result
    end
  end

  defp produce_to_kafka(instance, type, message) do
    {:ok, %{connection: connection, topic: topic}} = get(instance, __MODULE__)
    Elsa.produce(connection, topic, {type, message})
  end

  defp via(registry), do: {:via, Registry, {registry, __MODULE__}}
end
