use Mix.Config

config :openaperture_manager, OpenAperture.Manager.Endpoint,
  http: [port: System.get_env("PORT") || 4001]

# Print only warnings and errors during test
config :logger, level: :warn


config :openaperture_manager, OpenapertureManager.Repo,
	database: System.get_env("MANAGER_DATABASE_NAME")       || "openaperture_manager_test",
	username: System.get_env("MANAGER_USER_NAME")      		|| "postgres",
	password: System.get_env("MANAGER_PASSWORD")      		|| "postgres",
    hostname: System.get_env("MANAGER_DATABASE_HOST")       || "localhost"

config :openaperture_messaging, 
	private_key: "#{System.cwd!() <> "/priv/keys/testing.pem"}",
	public_key: "#{System.cwd!() <> "/priv/keys/testing.pub"}",
	keyname: "testing"
