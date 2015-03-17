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
     applications: [:phoenix, :cowboy, :logger, :ecto]]
  end

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [{:phoenix, "~> 0.10.0"},
     {:cowboy, "~> 1.0"},
     {:ecto, "~> 0.9.0"},
     {:uuid, "~> 0.1.5" },
     {:timex, "~> 0.13.3"},
     {:postgrex, "~> 0.8.0"},
     {:fleet_api, "0.0.3", git: "git@github.com:perceptive-cloud/fleet_api.git"},
     {:meck, "0.8.2", only: :test}]
  end
end
