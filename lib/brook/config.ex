defmodule Brook.Config do
  @moduledoc """
  Constructs a new Brook server config struct from a keyword list
  of inputs.
  """
  @default_driver %{module: Brook.Driver.Default, init_arg: []}

  @table_name :brook_config_table

  defstruct driver: nil,
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
      driver: Keyword.get(opts, :driver, @default_driver) |> Enum.into(%{}),
      event_handlers: Keyword.fetch!(opts, :handlers),
      storage: Keyword.fetch!(opts, :storage) |> Enum.into(%{}),
      dispatcher: Keyword.get(opts, :dispatcher, Brook.Dispatcher.Default)
    }
  end

  def store(%Brook.Config{} = config) do
    :ets.new(@table_name, [:set, :protected, :named_table])

    :ets.insert(@table_name, {:driver, config.driver})
    :ets.insert(@table_name, {:event_handlers, config.event_handlers})
    :ets.insert(@table_name, {:storage, config.storage})
    :ets.insert(@table_name, {:dispatcher, config.dispatcher})

    config
  end

  def storage() do
    get(:storage)
  end

  def driver() do
    get(:driver)
  end

  def event_handlers() do
    get(:event_handlers)
  end

  def dispatcher() do
    get(:dispatcher)
  end

  defp get(key) do
    case :ets.lookup(@table_name, key) do
      [] -> raise Brook.Uninitialized, message: "key(#{key}) is not stored in table"
      [{^key, value}] -> value
    end
  rescue
    e -> raise Brook.Uninitialized, message: inspect(e)
  end
end
