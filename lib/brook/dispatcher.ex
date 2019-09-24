defmodule Brook.Dispatcher do
  @moduledoc """
  Defines the Brook Dispatcher behaviour, requiring the
  `init/0` and `dispatch/1` functions be implemented by
  the client.
  """

  @doc """
  Start a Brook dispatcher.
  """
  @callback init(instance: Brook.instance()) :: :ok

  @doc """
  Distributes received messages across multiple nodes.
  """
  @callback dispatch(Brook.instance(), Brook.Event.t()) :: :ok
end

defmodule Brook.Dispatcher.Default do
  @moduledoc """
  Default implementation for the Brook.Dispatcher
  Creates and joins a process group named `:brook_servers`.
  Ensures all members of the process group receive notification
  of the received event by a member of the group.
  """
  import Brook.Config, only: [registry: 1]
  @behaviour Brook.Dispatcher

  @doc """
  Creates and joins the Brook server to the process group
  named `:brook_servers`.
  """
  @impl Brook.Dispatcher
  def init(args) do
    instance = Keyword.fetch!(args, :instance)
    :pg2.create(instance)
    [{pid, _}] = registry(instance) |> Registry.lookup(Brook.Server)
    :pg2.join(instance, pid)
  end

  @doc """
  Takes an event struct and forwards the event on to other
  member nodes of the `:brook_servers` process group after
  tagging the forwarded status of the event to `true`.
  """
  @impl Brook.Dispatcher
  def dispatch(instance, %Brook.Event{} = event) do
    forwarded_event = %{event | forwarded: true}

    (:pg2.get_members(instance) -- :pg2.get_local_members(instance))
    |> Enum.each(fn pid ->
      GenServer.cast(pid, {:process, forwarded_event})
    end)
  end
end

defmodule Brook.Dispatcher.Noop do
  @behaviour Brook.Dispatcher

  def init(_args) do
    :ok
  end

  def dispatch(_instance, _event) do
    :ok
  end
end
