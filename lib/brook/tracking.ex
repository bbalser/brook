defmodule Brook.Tracking do
  def create_table(config) do
    if_snapshot(config, fn ->
      :ets.new(__MODULE__, [:named_table, :set, :protected])
    end)
  end

  def record_action(config, key, action) do
    if_snapshot(config, fn ->
      :ets.insert(__MODULE__, {key, action})
    end)
  end

  def get_actions(config) do
    case config.snapshot do
      %{module: _module} ->
        :ets.match_object(__MODULE__, :_)
        |> Enum.map(fn {key, action} -> %{key: key, action: action} end)

      _ ->
        []
    end
  end

  def clear(config) do
    if_snapshot(config, fn ->
      :ets.delete_all_objects(__MODULE__)
    end)
  end

  defp if_snapshot(state, function) when is_function(function, 0) do
    if match?(%{module: module}, state.snapshot) do
      function.()
    end
  end
end
