require Logger

# The name of this module must be OpenapertureManager.Repo (instead of OpenAperture.Manager.Repo) because
# of how Ecto creates the repo name
defmodule OpenAperture.Manager.Repo do
  use Ecto.Repo, env: Mix.env, otp_app: OpenAperture.Manager
  #use Scrivener, page_size: 20
end