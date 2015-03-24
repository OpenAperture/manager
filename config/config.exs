# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures the endpoint
config :project_omelette_manager, ProjectOmeletteManager.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Ks/rsx+RENMwWd4jgh3crqd3EwKGY8Mdm22NTJbby6pf35CwP9RAlT+8oDJQ8+1f",
  debug_errors: false,
  pubsub: [name: ProjectOmeletteManager.PubSub,
           adapter: Phoenix.PubSub.PG2]

config :project_omelette_manager, ProjectOmeletteManager.Repo,
  adapter: Ecto.Adapters.Postgres

config :project_omelette_manager, ProjectOmeletteManager.Plugs.Authentication,
  oauth_validate_url: "https://www.googleapis.com/oauth2/v1/tokeninfo"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :cloudos_messaging, 
	private_key: System.get_env("CLOUDOS_MANAGER_MESSAGING_PRIVATE_KEY"),
	public_key: System.get_env("CLOUDOS_MANAGER_MESSAGING_PUBLIC_KEY"),
  keyname: System.get_env("CLOUDOS_MANAGER_MESSAGING_KEYNAME")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
