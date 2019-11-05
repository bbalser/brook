defmodule Brook.MixProject do
  use Mix.Project

  def project do
    [
      app: :brook,
      version: "0.4.9",
      elixir: "~> 1.8",
      description: description(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_file: {:no_warn, ".plt/dialyzer.plt"}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:brook_serializer, "~> 2.0"},
      {:redix, "~> 0.10.2"},
      {:elsa, "~> 0.11.0"},
      {:placebo, "~> 1.2", only: [:dev, :test, :integration]},
      {:assertions, "~> 0.14.1", only: [:test, :integration]},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:integration]},
      {:divo_redis, "~> 0.1.4", only: [:integration]},
      {:ex_doc, "~> 0.20.2", only: [:dev]},
      {:dialyxir, "~> 1.0.0-rc.6", only: [:dev], runtime: false}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]

  defp package do
    [
      maintainers: ["Brian Balser"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/bbalser/brook"}
    ]
  end

  defp description do
    "Brook provides an event stream client interface for distributed applications.
    Brook sends and receives messages with the event stream via a driver
    module and persists an application-specific view of the event stream via a
    storage module."
  end
end
