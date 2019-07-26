defmodule Brook.Tracking do
  @unacked_table :brook_tracking_unacked

  def create_table(config) do
    if_snapshot(config, fn ->
      :ets.new(__MODULE__, [:named_table, :set, :protected])
      :ets.new(@unacked_table, [:named_table, :bag, :protected])
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
        |> Enum.group_by(fn {_key, action} -> action end, fn {key, _action} -> key end)

      _ ->
        []
    end
  end

  def clear(config) do
    if_snapshot(config, fn ->
      :ets.delete_all_objects(__MODULE__)
      :ets.delete_all_objects(@unacked_table)
    end)
  end

  def add_event(config, event) do
    if_snapshot(config, fn ->
      :ets.insert(@unacked_table, {event.ack_ref, event.ack_data})
    end)
  end

  def ack_events(state) do
    :ets.match_object(@unacked_table, :_)
    |> Enum.group_by(fn {ack_ref, _ack_data} -> ack_ref end, fn {_ack_ref, ack_data} -> ack_data end)
    |> Enum.each(fn {ack_ref, ack_datas} ->
      apply(state.driver.module, :ack, [ack_ref, ack_datas])
    end)
  end

  defp if_snapshot(state, function) when is_function(function, 0) do
    if match?(%{module: _module}, state.snapshot) do
      function.()
    end
  end
end
