defmodule Brook.Dispatcher do
  @moduledoc """
  Defines the Brook Dispatcher behaviour, requiring the
  `init/0` and `dispatch/1` functions be implemented by
  the client.
  """
  @callback init() :: :ok

  @callback dispatch(Brook.Event.t()) :: :ok
end

defmodule Brook.Dispatcher.Default do
  @moduledoc """
  Default implementation for the Brook.Dispatcher
  Creates and joins a process group named `:brook_servers`.
  Ensures all members of the process group receive notification
  of the received event by a member of the group.
  """
  @behaviour Brook.Dispatcher

  @group :brook_servers

  @doc """
  Creates and joins the Brook server to the process group
  named `:brook_servers`.
  """
  @spec init() :: :ok | {:error, term()}
  def init() do
    :pg2.create(@group)
    [{pid, _}] = Registry.lookup(Brook.Registry, Brook.Server)
    :pg2.join(@group, pid)
  end

  @doc """
  Takes an event struct and forwards the event on to other
  member nodes of the `:brook_servers` process group after
  tagging the forwarded status of the event to `true`.
  """
  @spec dispatch(Brook.Event.t()) :: list(:ok)
  def dispatch(%Brook.Event{} = event) do
    forwarded_event = %{event | forwarded: true}

    (:pg2.get_members(@group) -- :pg2.get_local_members(@group))
    |> Enum.each(fn pid ->
      GenServer.cast(pid, {:process, forwarded_event})
    end)
  end
end
