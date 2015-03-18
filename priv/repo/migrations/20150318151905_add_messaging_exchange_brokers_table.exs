defmodule ProjectOmeletteManager.Repo.Migrations.AddMessagingExchangeBrokersTable do
  use Ecto.Migration

  def change do
    create table(:messaging_exchange_brokers) do
    	add :messaging_exchange_id, references(:messaging_exchanges), null: false
    	add :messaging_broker_id, references(:messaging_brokers), null: false
      timestamps
    end
  end
end
