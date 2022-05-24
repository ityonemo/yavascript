defmodule Yavascript.MixProject do
  use Mix.Project

  def project do
    [
      app: :yavascript,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [benchmark: :bench]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp elixirc_paths(:bench), do: ~w(lib bench)
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.3.0"},
      {:zigler, "~> 0.9.1"},
      {:benchee, "~> 1.1", only: [:bench]}
    ]
  end
end
