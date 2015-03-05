require Logger

defmodule ProjectOmeletteManager.Repo do
  use Ecto.Repo, env: Mix.env, otp_app: :project_omelette_manager
end