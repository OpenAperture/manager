defmodule OpenapertureManager.Repo.Migrations.AddMessagingBrokersTable do
  use Ecto.Migration

  def change do
    create table(:messaging_brokers) do
      add :name, :string, null: false
      add :failover_broker_id, references(:messaging_brokers)
      timestamps
    end

    create index(:messaging_brokers, [:failover_broker_id], unique: false)
  end
end
