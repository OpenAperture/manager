defmodule OpenAperture.Mixfile do
  use Mix.Project

  def project do
    [app: :openaperture_manager,
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
      mod: {OpenAperture.Manager, []},
      applications: [:phoenix, :cowboy, :logger, :ecto, :fleet_api, :crypto, :openaperture_auth, :openaperture_fleet]
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
     {:fleet_api, "~> 0.0.4"},
     {:rsa, "~> 0.0.1"},
     {:openaperture_auth, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/auth.git",
            ref: "0ded31f747cb0b781838b5799acadcda88dd7953", override: true},
     {:openaperture_fleet, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/fleet.git",
            ref: "0c648a0645106e51b858e3dbddefa570cdd2785a", override: true},      
     {:meck, "0.8.2", only: :test}
   ]
  end
end
