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
        #:openaperture_overseer_api,
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
      {:openaperture_auth, git: "https://github.com/OpenAperture/auth.git", ref: "dd7483eac3e7833fd5f2f9fb7347b17f68ff4bea", override: true},
      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet.git", ref: "adab7f2649016f43352f43def797f61acea8a292", override: true},      
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "b313cf059816389288d946ae022b702e22a7fe68", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git",  ref: "ae629a4127acceac8a9791c85e5a0d3b67d1ad16", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "bbc5b14934f253884f91c174906bbc3570fddd2f", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "9f71efeda9ddf5315d3f7c945c5336347c720ac9", override: true},

      {:meck, "0.8.2", only: :test},        
   ]
  end

 # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]  
end
