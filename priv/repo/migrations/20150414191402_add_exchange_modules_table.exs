defmodule OpenapertureManager.Repo.Migrations.AddExchangeModulesTable do
  use Ecto.Migration

  def change do
    create table(:messaging_exchange_modules) do
    	add :messaging_exchange_id, references(:messaging_exchanges), null: false
    	add :hostname, :string, null: false
    	add :type, :string, null: false
    	add :status, :string, null: false
    	add :workload, :string, null: false
      timestamps
    end

    create index(:messaging_exchange_modules, [:messaging_exchange_id, :hostname], unique: false)
  end
end
