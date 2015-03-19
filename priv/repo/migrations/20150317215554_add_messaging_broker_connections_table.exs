defmodule ProjectOmeletteManager.Repo.Migrations.AddMessagingBrokerConnectionsTable do
  use Ecto.Migration

  def change do
    create table(:messaging_broker_connections) do
    	add :messaging_broker_id, references(:messaging_brokers), null: false
      add :username, :string, null: false
      add :password, :string, null: false
      add :password_keyname, :string, null: true
      add :host, :string, null: false
      add :virtual_host, :string, null: false
      timestamps
    end
  end
end
