defmodule OpenAperture.Manager.Repo.Migrations.AddPortToBrokerOpts do
  use Ecto.Migration

  def change do
		alter table(:messaging_broker_connections) do
		  add :port, :integer
		end  	
  end
end