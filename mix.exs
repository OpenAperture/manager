defmodule ProjectOmeletteManager.Mixfile do
  use Mix.Project

  def project do
    [app: :project_omelette_manager,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: ["lib", "web"],
     compilers: [:phoenix] ++ Mix.compilers,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [mod: {ProjectOmeletteManager, []},
     applications: [:phoenix, :cowboy, :logger]]
  end

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [{:phoenix, "~> 0.9.0"},
     {:cowboy, "~> 1.0"},
     {:ecto, "~> 0.9.0"},
     {:postgrex, "~> 0.8.0"}]
  end
end
