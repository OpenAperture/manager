defmodule OpenAperture.Manager.Endpoint do
  use Phoenix.Endpoint, otp_app: :openaperture_manager

  plug PlugCors, headers: ["Authorization"]

  # Serve at "/" the given assets from "priv/static" directory
  plug Plug.Static,
    at: "/", from: :openaperture_manager,
    only: ~w(css images js favicon.ico robots.txt)

  plug Plug.Logger

  if code_reloading? do
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_openaperture_manager_key",
    signing_salt: "9dslX4Uf",
    encryption_salt: "gKrz9xoA"

  plug :router, OpenAperture.Manager.Router
end
