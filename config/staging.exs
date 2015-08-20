# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section:
#
#  config:openaperture_manager, OpenAperture.Manager.Endpoint,
#    ...
#    https: [port: 443,
#            keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#            certfile: System.get_env("SOME_APP_SSL_CERT_PATH")]
#
# Where those two env variables point to a file on
# disk for the key and cert.
  

# Do not pring debug messages in production
config :logger, level: :debug

# ## Using releases
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
#
#     config :phoenix, :serve_endpoints, true
#
# Alternatively, you can configure exactly which server to
# start per endpoint:
#
#     config :openaperture_manager, OpenAperture.Manager.Endpoint, server: true
#

config OpenAperture.Manager, OpenAperture.Manager.Repo,
  database: System.get_env("MANAGER_DATABASE_NAME") || "openaperture_manager_staging"

config :openaperture_manager_api, 
  manager_url: System.get_env("MANAGER_URL"),
  oauth_login_url: System.get_env("OAUTH_LOGIN_URL"),
  oauth_client_id: System.get_env("OAUTH_CLIENT_ID"),
  oauth_client_secret: System.get_env("OAUTH_CLIENT_SECRET")

config :openaperture_manager_overseer_api,
  autostart: true

config :openaperture_overseer_api,
  exchange_id: System.get_env("EXCHANGE_ID"),
  broker_id: System.get_env("BROKER_ID")