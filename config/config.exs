# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config OpenAperture.Manager, OpenAperture.Manager.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  url: [host: "localhost"],
  secret_key_base: "Ks/rsx+RENMwWd4jgh3crqd3EwKGY8Mdm22NTJbby6pf35CwP9RAlT+8oDJQ8+1f",
  debug_errors: false,
  check_origin: false,
  pubsub: [name: OpenAperture.Manager.PubSub,
           adapter: Phoenix.PubSub.PG2],
  root: Path.expand("..", __DIR__)

config OpenAperture.Manager, OpenAperture.Manager.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("MANAGER_DATABASE_NAME") || "openaperture_manager",
  username: System.get_env("MANAGER_USER_NAME")     || "postgres",
  password: System.get_env("MANAGER_PASSWORD")      || "postgres",
  hostname: System.get_env("MANAGER_DATABASE_HOST") || "localhost"

config OpenAperture.Manager,
  oauth_validate_url: System.get_env("MANAGER_OAUTH_VALIDATE_URL") || "https://www.googleapis.com/oauth2/v1/tokeninfo",
  build_log_monitor_autostart: false

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :openaperture_messaging, 
  private_key: System.get_env("MANAGER_MESSAGING_PRIVATE_KEY"),
  public_key: System.get_env("MANAGER_MESSAGING_PUBLIC_KEY"),
  keyname: System.get_env("MANAGER_MESSAGING_KEYNAME")

config :openaperture_manager_api,
  manager_url: System.get_env("MANAGER_URL")                 || "https://openaperture-mgr.host.co",
  oauth_login_url: System.get_env("OAUTH_LOGIN_URL")         || "https://auth.host.co",
  oauth_client_id: System.get_env("OAUTH_CLIENT_ID")         || "id",
  oauth_client_secret: System.get_env("OAUTH_CLIENT_SECRET") || "secret"

config :openaperture_manager_overseer_api,
  autostart: false

config :swaggerdoc,
  swagger_version: "2.0",
  project_version: "1.0.0",
  project_name: "OpenAperture Manager",
  project_desc: "The REST API for the OpenAperture Manager",
  project_terms: "https://github.com/OpenAperture/manager/blob/master/LICENSE",
  project_contact_name: "OpenAperture",
  project_contact_email: "openaperture@lexmark.com",
  project_contact_url: "http://openaperture.io",
  project_license_name: "Mozilla Public License, v. 2.0",
  project_license_url: "https://github.com/OpenAperture/manager/blob/master/LICENSE",
  host: "openaperture.io",
  base_path: "/",
  schemes: ["https"],
  consumes: ["application/json"],
  produces: ["application/json"]
  
# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
