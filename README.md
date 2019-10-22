# Brook

Brook provides an event stream client interface for distributed applications
to communicate indirectly and asynchronously. Brook sends and receives messages
with the event stream (typically a message queue service) via a driver module
and persists an application-specific view of the event stream via a storage module
(defaulting to ETS).

## Installation

The package can be installed from Hex by adding `brook` to
your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:brook, "~> 0.4"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/brook](https://hexdocs.pm/brook).

## Testing

Elsa uses the standard ExUnit testing library for unit testing. For integration testing
interactions with Kafka, it uses the [`divo`](https://github.com/smartcitiesdata/divo) library.
Run tests with the command `mix test.integration`.

## Sample Configuration

Brook is configured within the application environment by defining
a keyword list with three primary keys: driver, handler, and storage.

```elixir
config :my_app, :brook,
  driver: [
    module: Brook.Driver.Json,
    init_arg: []
  ],
  handler: [MyApp.Event.Handler],
  storage: [
    modules: Brook.Storage.Ets,
    init_arg: []
  ]
```

### Driver
The Brook driver implements a behaviour that sends messages to the event stream.
Events are Brook structs that contain an event type, an author (or source), a
creation timestamp, the event data, and an ack reference and ack data (following
the lead of the [`broadway`](https://github.com/plataformatec/broadway) library.)

The default driver sends the event message to the Brook server via `Genserver.cast`

Additional drivers provided at this time are a json-encoding version of the default
driver and a Kafka driver using the [`elsa`](https://github.com/bbalser/elsa) library.

### Handler
The Brook handler implements a behaviour that provides a `handle_event/1` function.
Handlers receive a Brook event and take appropriate action according to the implementing
application's business logic.

Applications implement as many function heads for the event handler as necessary and return
one of four tuples depending on how the storage module should treat the event with
respect to persistence. Events can:
- create a record in the view state via the `{:create, collection, key, value}` return
- update an existing record via the `{:merge, collection, key, value}` return
- delete a record via the `{:delete, collection, key}` return
- discard the record and do not effect the persistent view via the `:discard` return

### Storage
The Brook storage module implements yet another behaviour that persists event data to
an application view state specific to the application importing the Brook library, allowing
the application to only store information received from the event stream that is relevant to
its own domain and retrieve it when necessary.

Storage modules implement basic CRUD operations that correlate to the return values of
the event handler module.

The default module uses ETS for fast, local, in-memory storage and retrieval (great for
testing purposes!) with an additional Redis-based module as well.
