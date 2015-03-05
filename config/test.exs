use Mix.Config

config :project_omelette_manager, ProjectOmeletteManager.Endpoint,
  http: [port: System.get_env("PORT") || 4001]

# Print only warnings and errors during test
config :logger, level: :warn


config :project_omelette_manager, ProjectOmeletteManager.Repo,
	database: "project_omelette_manager_test",
	username: "postgres",
	password: "postgres"