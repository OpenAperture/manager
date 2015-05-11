use Mix.Config

config OpenAperture.Manager, OpenAperture.Manager.Endpoint,
  http: [port: System.get_env("PORT") || 4001]

# Print only warnings and errors during test
config :logger, level: :warn


config OpenAperture.Manager, OpenAperture.Manager.Repo,
	database: System.get_env("MANAGER_DATABASE_NAME")       || "openaperture_manager_test",
	username: System.get_env("MANAGER_USER_NAME")      		|| "postgres",
	password: System.get_env("MANAGER_PASSWORD")      		|| "postgres",
  hostname: System.get_env("MANAGER_DATABASE_HOST")       || "localhost"

config :openaperture_messaging, 
	private_key: "#{System.cwd!() <> "/priv/keys/testing.pem"}",
	public_key: "#{System.cwd!() <> "/priv/keys/testing.pub"}",
	keyname: "testing"

config :openaperture_manager_api, 
	manager_url: System.get_env("MANAGER_URL") || "https://openaperture-mgr.host.co",
	oauth_login_url: System.get_env("OAUTH_LOGIN_URL") || "https://auth.host.co",
	oauth_client_id: System.get_env("OAUTH_CLIENT_ID") ||"id",
	oauth_client_secret: System.get_env("OAUTH_CLIENT_SECRET") || "secret"

config OpenAperture.Manager, 
	exchange_id: "1",
	broker_id: "1"

config :openaperture_manager_overseer_api,
  autostart: false