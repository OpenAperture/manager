defmodule OpenAperture.Mixfile do
  use Mix.Project

  def project do
    [app: OpenAperture.Manager,
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
      applications: [
        :phoenix, 
        :cowboy, 
        :logger, 
        :ecto, 
        :fleet_api, 
        :crypto, 
        :openaperture_auth, 
        :openaperture_fleet, 
        :openaperture_messaging,
        :openaperture_manager_api,
        :openaperture_workflow_orchestrator_api
    ]
   ]
  end

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [
      {:ex_doc, github: "elixir-lang/ex_doc", only: [:test]},
      {:earmark, github: "pragdave/earmark", tag: "v0.1.8", only: [:test]},

      {:phoenix, "~> 0.11.0"},
      {:phoenix_live_reload, "~> 0.3"},
      {:cowboy, "~> 1.0"},
      {:ecto, "~> 0.10.1"},
      {:uuid, "~> 0.1.5" },
      {:timex, "~> 0.13.3", override: true},
      {:postgrex, "~> 0.8.0"},
      {:fleet_api, "~> 0.0.4"},
      {:rsa, "~> 0.0.1"},
      {:plug_cors, git: "https://github.com/bryanjos/plug_cors", tag: "v0.7.0"},
      {:openaperture_auth, git: "https://github.com/OpenAperture/auth.git", ref: "6b58ad987987fb39208967e94f8cae29835aad2f", override: true},
      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet.git", ref: "6f487b355d4dd02d8455f2f86dfc23334a446fc9", override: true},      
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "e791d59c5bfaec9daa5cf7397401795ccd064a2a", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git",  ref: "5d442cfbdd45e71c1101334e185d02baec3ef945", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "4d65d2295f2730bc74ec695c32fa0d2478158182", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "b5b027d860c367d34ec116292fd8e7e4ca07623f", override: true},

      {:meck, "0.8.2", only: :test},        
   ]
  end

 # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]  
end
