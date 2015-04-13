use Mix.Config

config :openaperture_manager, OpenAperture.Manager.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: true,
  cache_static_lookup: false

config :openaperture_manager, OpenapertureManager.Repo,
	database: System.get_env("MANAGER_DATABASE_NAME")       || "openaperture_manager",
	username: System.get_env("MANAGER_USER_NAME")      		|| "postgres",
	password: System.get_env("MANAGER_PASSWORD")      		|| "postgres",
    hostname: System.get_env("MANAGER_DATABASE_HOST")       || "localhost"

# Enables code reloading for development
config :phoenix, :code_reloader, true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :logger, level: :debug