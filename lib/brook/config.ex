defmodule Brook.Config do
  @moduledoc """
  Constructs a new Brook server config struct from a keyword list
  of inputs.
  """
  @default_driver %{module: Brook.Driver.Default, init_arg: []}
  @default_storage %{module: Brook.Storage.Ets, init_arg: []}
  @default_dispatcher Brook.Dispatcher.Default

  defstruct name: nil,
            driver: nil,
            event_handlers: nil,
            storage: nil,
            dispatcher: nil

  @doc """
  Take a keyword list and extracts values necessary to configure a Brook
  server. Provides default values for the `driver` and `dipatcher` but fails
  if `event_handler` or `storage` are not supplied by the user.
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      driver: Keyword.get(opts, :driver, @default_driver) |> Enum.into(%{}),
      event_handlers: Keyword.fetch!(opts, :handlers),
      storage: Keyword.get(opts, :storage, @default_storage) |> Enum.into(%{}),
      dispatcher: Keyword.get(opts, :dispatcher, @default_dispatcher)
    }
  end

  def store(%Brook.Config{} = config) do
    table = table_name(config.name)
    :ets.new(table, [:set, :protected, :named_table])

    :ets.insert(table, {:driver, config.driver})
    :ets.insert(table, {:event_handlers, config.event_handlers})
    :ets.insert(table, {:storage, config.storage})
    :ets.insert(table, {:dispatcher, config.dispatcher})

    config
  end

  def registry(name) do
    :"brook_registry_#{name}"
  end

  def storage(name) do
    get(name, :storage)
  end

  def driver(name) do
    get(name, :driver)
  end

  def event_handlers(name) do
    get(name, :event_handlers)
  end

  def dispatcher(name) do
    get(name, :dispatcher)
  end

  defp table_name(name), do: :"brook_config_table_#{name}"

  defp get(name, key) do
    case :ets.lookup(table_name(name), key) do
      [] -> raise Brook.Uninitialized, message: "key(#{key}) is not stored in table"
      [{^key, value}] -> value
    end
  rescue
    e -> raise Brook.Uninitialized, message: inspect(e)
  end
end
