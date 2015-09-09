use Mix.Config

config OpenAperture.Manager, OpenAperture.Manager.Endpoint,
  debug_errors: true,
  cache_static_lookup: false,
  code_reloader: true,
  live_reload: [
    # url is optional
    url: "ws://localhost:4000", 
    # `:patterns` replace `:paths` and are required for live reload
    patterns: [~r{priv/static/.*(js|css|png|jpeg|jpg|gif)$},
               ~r{web/views/.*(ex)$},
               ~r{web/templates/.*(eex)$}]]  

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :logger, level: :info

config OpenAperture.Manager,
  build_log_monitor_autostart: false,
  disable_cache: false