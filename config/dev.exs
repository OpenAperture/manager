use Mix.Config

config :openaperture_manager, OpenAperture.Manager.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: true,
  cache_static_lookup: false,
  code_reloader: true,
  live_reload: [
    # url is optional
    url: "ws://localhost:4000", 
    # `:patterns` replace `:paths` and are required for live reload
    patterns: [~r{priv/static/.*(js|css|png|jpeg|jpg|gif)$},
               ~r{web/views/.*(ex)$},
               ~r{web/templates/.*(eex)$}]]  

config :openaperture_manager, OpenapertureManager.Repo,
	database: System.get_env("MANAGER_DATABASE_NAME")       || "openaperture_manager",
	username: System.get_env("MANAGER_USER_NAME")      		|| "postgres",
	password: System.get_env("MANAGER_PASSWORD")      		|| "postgres",
    hostname: System.get_env("MANAGER_DATABASE_HOST")       || "localhost"

# Enables code reloading for development
config :openaperture_manager, OpenAperture.Manager.Endpoint, code_reloader: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :logger, level: :debug