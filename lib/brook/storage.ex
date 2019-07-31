defmodule Brook.Storage do
  @callback start_link(term()) :: GenServer.on_start()

  @callback child_spec(term()) :: Supervisor.child_spec()

  @callback persist(Brook.Event.t(), Brook.view_collection(), Brook.view_key(), Brook.view_value()) ::
              :ok | {:error, Brook.reason()}

  @callback delete(Brook.view_collection(), Brook.view_key()) :: :ok | {:error, Brook.reason()}

  @callback get(Brook.view_collection(), Brook.view_key()) :: Brook.view_value()

  @callback get_all(Brook.view_collection()) :: %{required(Brook.view_key()) => Brook.view_value()}

  @callback get_events(Brook.view_collection(), Brook.view_key()) :: list(Brook.Event.t())
end
