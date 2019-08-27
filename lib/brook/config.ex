defmodule Brook.Config do
  @moduledoc """
  Constructs a new Brook server config struct from a keyword list
  of inputs.
  """
  @default_driver %{module: Brook.Driver.Default, init_arg: []}

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
end
