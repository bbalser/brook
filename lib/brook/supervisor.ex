defmodule Brook.Supervisor do
  @moduledoc """
  A Brook application supervisor, managing the process registry,
  storage and driver module processes, and the server process.
  """
  use Supervisor

  @doc """
  Start a Brook supervisor and link it to the current process.
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize the Brook supervisor with all necessary child processes.
  """
  def init(opts) do
    config =
      Brook.Config.new(opts)
      |> Brook.Config.store()

    children =
      [
        {Registry, [keys: :unique, name: config.registry]},
        {config.storage.module, create_init_arg(config.registry, config.storage)},
        {Brook.Server, config},
        {config.driver.module, config.driver.init_arg}
      ]
      |> List.flatten()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp create_init_arg(registry, plugin) do
    Map.get(plugin, :init_arg, [])
    |> Keyword.put(:registry, registry)
  end
end
