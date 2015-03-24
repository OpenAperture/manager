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
    [
      mod: {ProjectOmeletteManager, []},
      applications: [:phoenix, :cowboy, :logger, :ecto, :fleet_api, :crypto]
   ]
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
     {:fleet_api, "0.0.2"},
     {:rsa, "~> 0.0.1"},
     {:cloudos_auth, git: "https://github.com/UmbrellaCorporation-SecretProjectLab/cloudos_auth.git", ref: "00d0ef0c848f571e1c3830df72185276580f913f"},
      
     {:meck, "0.8.2", only: :test}
   ]
  end
end
