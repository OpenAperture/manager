defmodule OpenapertureManager.Repo.Migrations.AddExchangeFailover do
  use Ecto.Migration

  def change do
		alter table(:messaging_exchanges) do
		  add :failover_exchange_id, references(:messaging_exchanges)
		end  	
  end
end
