use Mix.Config

config :openaperture_manager, OpenAperture.Manager.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  secret_key_base: "Ks/rsx+RENMwWd4jgh3crqd3EwKGY8Mdm22NTJbby6pf35CwP9RAlT+8oDJQ8+1f"

config :openaperture_manager, OpenapertureManager.Repo,
	database: System.get_env("MANAGER_DATABASE_NAME")       || "openaperture_manager",
	username: System.get_env("MANAGER_USER_NAME")      		|| "postgres",
	password: System.get_env("MANAGER_PASSWORD")      		|| "postgres",
  hostname: System.get_env("MANAGER_DATABASE_HOST")       || "localhost"


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
config :logger, level: :info

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
