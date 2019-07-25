defmodule Brook.Driver.Default do
  use GenServer
  @behaviour Brook.Driver

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    {:ok, []}
  end
end
