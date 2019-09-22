defmodule Brook.Config do
  @moduledoc """
  Constructs a new Brook server config struct from a keyword list
  of inputs.
  """
  @default_driver %{module: Brook.Driver.Default, init_arg: []}
  @default_storage %{module: Brook.Storage.Ets, init_arg: []}
  @default_dispatcher Brook.Dispatcher.Default

  use GenServer, restart: :transient

  defstruct instance: nil,
            driver: nil,
            event_handlers: nil,
            storage: nil,
            dispatcher: nil,
            registry: nil

  @doc """
  Take a keyword list and extracts values necessary to configure a Brook
  server. Provides default values for the `driver` and `dipatcher` but fails
  if `event_handler` or `storage` are not supplied by the user.
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    instance = Keyword.fetch!(opts, :instance)
    %__MODULE__{
      instance: instance,
      driver: Keyword.get(opts, :driver, @default_driver) |> Enum.into(%{}),
      event_handlers: Keyword.fetch!(opts, :handlers),
      storage: Keyword.get(opts, :storage, @default_storage) |> Enum.into(%{}),
      dispatcher: Keyword.get(opts, :dispatcher, @default_dispatcher),
      registry: registry(instance)
    }
  end

  def put(instance, key, value) do
    Registry.put_meta(registry(instance), key, value)
  end

  def get(instance, key) do
    Registry.meta(registry(instance), key)
  end

  def registry(instance) do
    :"brook_registry_#{instance}"
  end

  def storage(instance) do
    get_value(instance, :storage)
  end

  def driver(instance) do
    get_value(instance, :driver)
  end

  def event_handlers(instance) do
    get_value(instance, :event_handlers)
  end

  def dispatcher(instance) do
    get_value(instance, :dispatcher)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    config = Keyword.fetch!(args, :config)

    Registry.put_meta(config.registry, :driver, config.driver)
    Registry.put_meta(config.registry, :event_handlers, config.event_handlers)
    Registry.put_meta(config.registry, :storage, config.storage)
    Registry.put_meta(config.registry, :dispatcher, config.dispatcher)

    {:ok, [], {:continue, :done}}
  end

  def handle_continue(:done, state) do
    {:stop, :normal, state}
  end

  defp get_value(instance, key) do
    case Registry.meta(registry(instance), key) do
      {:ok, value} -> value
      :error -> raise Brook.Uninitialized, message: "key(#{key}) is not stored in registry"
    end
  rescue
    e -> raise Brook.Uninitialized, message: inspect(e)
  end
end
