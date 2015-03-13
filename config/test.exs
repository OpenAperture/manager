use Mix.Config

config :project_omelette_manager, ProjectOmeletteManager.Endpoint,
  http: [port: System.get_env("PORT") || 4001]

# Print only warnings and errors during test
config :logger, level: :warn


config :project_omelette_manager, ProjectOmeletteManager.Repo,
	database: System.get_env("CLOUDOS_MANAGER_DATABASE_NAME")       || "project_omelette_manager_test",
	username: System.get_env("CLOUDOS_MANAGER_USER_NAME")      		|| "postgres",
	password: System.get_env("CLOUDOS_MANAGER_PASSWORD")      		|| "postgres"