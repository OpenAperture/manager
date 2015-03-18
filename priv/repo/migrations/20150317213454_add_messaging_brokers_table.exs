defmodule ProjectOmeletteManager.Repo.Migrations.AddMessagingBrokersTable do
  use Ecto.Migration

  def change do
    create table(:messaging_brokers) do
      add :name, :string, null: false
      add :failover_broker_id, references(:messaging_brokers)
      timestamps
    end
  end
end
