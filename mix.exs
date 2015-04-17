defmodule OpenAperture.Mixfile do
  use Mix.Project

  def project do
    [app: :openaperture_manager,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: ["lib", "web"],
     compilers: [:phoenix] ++ Mix.compilers,
     deps: deps,
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
   ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      mod: {OpenAperture.Manager, []},
      applications: [:phoenix, :cowboy, :logger, :ecto, :fleet_api, :crypto, :openaperture_auth, :openaperture_fleet, :openaperture_messaging]
   ]
  end

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [
      {:ex_doc, github: "elixir-lang/ex_doc", only: [:dev, :test]},
      {:markdown, github: "devinus/markdown", only: [:dev, :test]},

      {:phoenix, "~> 0.11.0"},
      {:phoenix_live_reload, "~> 0.3"},
      {:cowboy, "~> 1.0"},
      {:ecto, "~> 0.10.1"},
      {:uuid, "~> 0.1.5" },
      {:timex, "~> 0.13.3"},
      {:postgrex, "~> 0.8.0"},
      {:fleet_api, "~> 0.0.4"},
      {:rsa, "~> 0.0.1"},
      {:openaperture_auth, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/auth.git",
        ref: "0ded31f747cb0b781838b5799acadcda88dd7953", override: true},
      {:openaperture_fleet, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/fleet.git",
        ref: "0c648a0645106e51b858e3dbddefa570cdd2785a", override: true},      
      {:openaperture_messaging, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/messaging.git",
        ref: "6b013743053bd49c964cdf49766a8a201ef33f71", override: true},
      {:meck, "0.8.2", only: :test},
      {:openaperture_manager_api, git: "https://#{System.get_env("GITHUB_OAUTH_TOKEN")}:x-oauth-basic@github.com/OpenAperture/manager_api.git", 
        ref: "f67a4570ec4b46cb2b2bb746924b322eec1e3178", override: true},
   ]
  end

 # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]  
end
