require Logger

defmodule ProjectOmeletteManager.Repo do
  use Ecto.Repo, env: Mix.env, otp_app: :project_omelette_manager

  def vinsert(model, opts \\ []) do
  	vmodel = IO.puts "validate here"
    insert(model, opts)
  end
end