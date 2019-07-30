defmodule Brook.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    config = Brook.Config.new(opts)

    children =
      [
        {Registry, [keys: :unique, name: Brook.Registry]},
        {config.storage.module, config.storage.init_arg},
        {Brook.Server, config},
        {config.driver.module, config.driver.init_arg}
      ]
      |> List.flatten()

    Supervisor.init(children, strategy: :one_for_one)
  end
end
