defmodule Brook.Snapshot.RedisStorage do
  @behaviour Brook.Snapshot.Storage

  def init(init_arg) do
    {:ok, init_arg}
  end

  def store(entries, state) do
    entries
    |> Enum.map(fn {key, value} -> {key, %{key: key, value: value}} end)
    |> Enum.each(fn {key, value} ->
      Redix.command!(state.redix, ["SET", "#{state.namespace}:#{key}", :erlang.term_to_binary(value)])
    end)
  end

  def get_latest(state) do
    case Redix.command!(state.redix, ["KEYS", "#{state.namespace}:*"]) do
      [] ->
        []

      keys ->
        Redix.command!(state.redix, ["MGET" | keys])
        |> Enum.map(&:erlang.binary_to_term/1)
        |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
        |> Enum.into(%{})
    end
  end
end
