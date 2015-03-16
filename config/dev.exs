use Mix.Config

config :project_omelette_manager, ProjectOmeletteManager.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: true,
  cache_static_lookup: false

config :project_omelette_manager, ProjectOmeletteManager.Repo,
	database: System.get_env("CLOUDOS_MANAGER_DATABASE_NAME")       || "project_omelette_manager",
	username: System.get_env("CLOUDOS_MANAGER_USER_NAME")      		|| "postgres",
	password: System.get_env("CLOUDOS_MANAGER_PASSWORD")      		|| "postgres",
    hostname: System.get_env("CLOUDOS_MANAGER_DATABASE_HOST")       || "localhost"

# Enables code reloading for development
config :phoenix, :code_reloader, true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
