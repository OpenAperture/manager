defmodule OpenAperture.Manager.Endpoint do
  use Phoenix.Endpoint, otp_app: OpenAperture.Manager

  plug PlugCors, headers: ["Authorization", "Content-Type", "Accept", "Origin",
                 "User-Agent", "DNT","Cache-Control", "X-Mx-ReqToken",
                 "Keep-Alive", "X-Requested-With", "If-Modified-Since",
                 "X-CSRF-Token", "X-Verbose-Error-Handling"],
                 expose_headers: ["Location", "location"]

  # Serve at "/" the given assets from "priv/static" directory
  plug Plug.Static,
    at: "/", from: OpenAperture.Manager,
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
    key: "_open_aperture_manager_key",
    signing_salt: "9dslX4Uf",
    encryption_salt: "gKrz9xoA"

  plug :router, OpenAperture.Manager.Router
end
