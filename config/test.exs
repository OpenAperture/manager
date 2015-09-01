use Mix.Config

config OpenAperture.Manager, OpenAperture.Manager.Endpoint,
  http: [port: System.get_env("PORT") || 4001]

# Print only warnings and errors during test
config :logger, level: :warn

config OpenAperture.Manager, OpenAperture.Manager.Repo,
  database: System.get_env("MANAGER_TEST_DATABASE_NAME") || "openaperture_manager_test",
  username: System.get_env("MANAGER_TEST_USER_NAME")     || "postgres",
  password: System.get_env("MANAGER_TEST_PASSWORD")      || "postgres",
  hostname: System.get_env("MANAGER_TEST_DATABASE_HOST") || "localhost"

config :openaperture_messaging, 
  private_key: "#{System.cwd!() <> "/priv/keys/testing.pem"}",
  public_key: "#{System.cwd!() <> "/priv/keys/testing.pub"}",
  keyname: "testing"

config OpenAperture.Manager, 
  exchange_id: "1",
  broker_id: "1",
  build_log_monitor_autostart: false,
  cache_queue_monitor_autostart: false