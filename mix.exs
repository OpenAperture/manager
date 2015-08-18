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
        :crypto, 
        :openaperture_auth, 
        :openaperture_messaging,
        :openaperture_manager_api,
        :openaperture_workflow_orchestrator_api,
        :openaperture_product_deployment_orchestrator_api
    ]
   ]
  end

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [
      {:ex_doc, "0.7.3", only: :test},
      {:earmark, "0.1.17", only: :test},
      {:phoenix, "~> 0.13.1"},

      {:plug, "0.13.1"},
      #need to lock-down plug to resolve:
      #== Compilation error on file lib/phoenix/code_reloader.ex ==
      #** (CompileError) lib/phoenix/code_reloader.ex:61: function full_path/1 undefined
      #    (stdlib) lists.erl:1337: :lists.foreach/2
      #    (stdlib) erl_eval.erl:669: :erl_eval.do_apply/6

      {:phoenix_live_reload, "~> 0.4.0"},
      {:cowboy, "~> 1.0"},
      {:ecto, "~> 0.13.0"},
      {:uuid, "~> 0.1.5" },
      {:timex, "~> 0.13.3", override: true},
      {:postgrex, "~> 0.8.0"},
      {:rsa, "~> 0.0.1"},
      {:poison, "~> 1.4.0", override: true},
      {:scrivener, "~> 0.10.0", override: true},
      
      {:plug_cors, git: "https://github.com/bryanjos/plug_cors", tag: "v0.7.0"},
      {:openaperture_auth, git: "https://github.com/OpenAperture/auth.git", ref: "5872c61ee5b6968ba6cc36fe49bdb2690d6cb331", override: true},
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "3d3a84eabf4ba0a3a827a61c4d99cdbf0ab49a0d", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git",  ref: "7bee243e9ae57938b09799ac01a9edc2f722720c", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "4b9146507ab50789fec4696b96f79642add2b502", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "df4033a048145c62361e7e161c60142b7fc501e4", override: true},
      {:openaperture_product_deployment_orchestrator_api, git: "https://github.com/OpenAperture/product_deployment_orchestrator_api", ref: "3cfc61a765b0fe80581eacb1bc53e5436eb6d389", override: true},
      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet", ref: "324acdae0ceecb6a954d804d56d9d2fceaeb937c", override: true},
      {:timex_extensions, git: "https://github.com/OpenAperture/timex_extensions", ref: "1665c1df90397702daf492c6f940e644085016cd", override: true},
                  

      {:meck, "0.8.3", override: true},        
   ]
  end

 # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]  
end
