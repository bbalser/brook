defmodule Brook.MixProject do
  use Mix.Project

  def project do
    [
      app: :brook,
      version: "0.1.0",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:redix, "~> 0.10.2"},
      {:jason, "~> 1.1"},
      {:elsa, "~> 0.7.1"},
      {:placebo, "~> 1.2", only: [:dev, :test]},
      {:assertions, "~> 0.14.1", only: [:test, :integration]},
      {:divo, "~> 1.1", only: [:dev, :integration]},
      {:divo_kafka, "~> 0.1.5", only: [:integration]},
      {:divo_redis, "~> 0.1.4", only: [:integration]}
    ]
  end

  defp elixirc_paths(env) when env in [:test, :integration], do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_), do: ["test/unit"]
end
