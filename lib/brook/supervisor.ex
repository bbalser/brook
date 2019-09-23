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
    instance = Keyword.fetch!(opts, :instance)
    Supervisor.start_link(__MODULE__, opts, name: :"brook_supervisor_#{instance}")
  end

  @doc """
  Initialize the Brook supervisor with all necessary child processes.
  """
  def init(opts) do
    config =
      Brook.Config.new(opts)

    children =
      [
        {Registry, [keys: :unique, name: config.registry]},
        {Brook.Config, config: config},
        {config.storage.module, create_init_arg(config.instance, config.storage)},
        {Brook.Server, config},
        {config.driver.module, create_init_arg(config.instance, config.driver)}
      ]
      |> List.flatten()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp create_init_arg(instance, plugin) do
    Map.get(plugin, :init_arg, [])
    |> Keyword.put(:instance, instance)
  end
end
