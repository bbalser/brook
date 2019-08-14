defmodule Brook do
  @type event_type :: String.t()
  @type event :: term()
  @type author :: String.Chars.t()

  @type view_collection :: String.Chars.t()
  @type view_key :: String.Chars.t()
  @type view_value :: term()

  @type reason :: term()

  defmodule UnsupportedMerge do
    defexception [:message]
  end

  defdelegate start_link(opts), to: Brook.Supervisor

  defdelegate child_spec(args), to: Brook.Supervisor

  @spec get(view_collection(), view_key()) :: {:ok, view_value()} | {:error, reason()}
  defdelegate get(collection, key), to: Brook.Server

  def get!(collection, key) do
    case get(collection, key) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @spec get_events(view_collection(), view_key()) :: {:ok, list(Brook.Event.t())} | {:error, reason()}
  defdelegate get_events(collection, key), to: Brook.Server

  @spec get_events!(view_collection(), view_key()) :: list(Brook.Event.t())
  def get_events!(collection, key) do
    case get_events(collection, key) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @spec get_all(view_collection()) :: {:ok, %{required(view_key()) => view_value()}} | {:error, reason()}
  defdelegate get_all(collection), to: Brook.Server

  @spec get_all!(view_collection()) :: %{required(view_key()) => view_value()}
  def get_all!(collection) do
    case get_all(collection) do
      {:ok, value} -> value
      {:error, reason} -> raise reason
    end
  end

  @spec get_all_values(view_collection()) :: {:ok, [view_value()]} | {:error, reason()}
  def get_all_values(collection) do
    case get_all(collection) do
      {:ok, map} -> {:ok, Map.values(map)}
      error -> error
    end
  end

  @spec get_all_values!(view_collection()) :: [view_value()]
  def get_all_values!(collection) do
    case get_all_values(collection) do
      {:ok, values} -> values
      {:error, reason} -> raise reason
    end
  end
end
