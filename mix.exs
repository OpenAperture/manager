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
      {:ex_doc, "0.8.4", only: :test},
      {:earmark, "0.1.17", only: :test},
      {:phoenix, "~> 1.0.0"},

      {:plug, "~> 1.0"},
      #need to lock-down plug to resolve:
      #== Compilation error on file lib/phoenix/code_reloader.ex ==
      #** (CompileError) lib/phoenix/code_reloader.ex:61: function full_path/1 undefined
      #    (stdlib) lists.erl:1337: :lists.foreach/2
      #    (stdlib) erl_eval.erl:669: :erl_eval.do_apply/6

      {:phoenix_live_reload, "~> 1.0.0"},
      {:cowboy, "~> 1.0"},
      {:ecto, "~> 1.0.0", override: true},
      {:uuid, "~> 0.1.5" },
      {:timex, "~> 0.13.3", override: true},
      {:postgrex, "~> 0.9.1", override: true},
      {:rsa, "~> 0.0.1"},
      {:poison, "~> 1.4.0", override: true},
      {:scrivener, "~> 0.10.0", override: true},
      
      {:plug_cors, git: "https://github.com/bryanjos/plug_cors", tag: "v0.7.0"},
      {:openaperture_auth, git: "https://github.com/OpenAperture/auth.git", ref: "b8afe858fc875b80ef7ed879b34b7d8a1576819d", override: true},
      {:openaperture_messaging, git: "https://github.com/OpenAperture/messaging.git", ref: "380ce611a038dd8f7afb4fa7f660aeac06475af0", override: true},
      {:openaperture_manager_api, git: "https://github.com/OpenAperture/manager_api.git",  ref: "dc06f0a484410e7707dab8e96807d54a564557ed", override: true},
      {:openaperture_overseer_api, git: "https://github.com/OpenAperture/overseer_api.git", ref: "67e1ec93cf1e12e5b0e86165f33ede703a886092", override: true},
      {:openaperture_workflow_orchestrator_api, git: "https://github.com/OpenAperture/workflow_orchestrator_api.git", ref: "925492cb2551aaedb99e8af5a0b93f7d601a6585", override: true},
      {:openaperture_product_deployment_orchestrator_api, git: "https://github.com/OpenAperture/product_deployment_orchestrator_api", ref: "3cfc61a765b0fe80581eacb1bc53e5436eb6d389", override: true},
      {:openaperture_fleet, git: "https://github.com/OpenAperture/fleet", ref: "9fa880eef5aa23bf89e3f121df04fdc542c74c73", override: true},
      {:timex_extensions, git: "https://github.com/OpenAperture/timex_extensions", ref: "bf6fe4b5a6bd7615fc39877f64b31e285b7cc3de", override: true},
                  

      {:meck, "0.8.3", override: true},        
   ]
  end

 # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]  
end
