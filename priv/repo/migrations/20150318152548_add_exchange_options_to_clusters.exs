defmodule ProjectOmeletteManager.Repo.Migrations.AddExchangeOptionsToClusters do
  use Ecto.Migration

  def change do
		alter table(:etcd_clusters) do
		  add :allow_docker_builds, :boolean, null: true
		  add :messaging_exchange_id, references(:messaging_exchanges), null: true
		end

  	create index(:etcd_clusters, [:allow_docker_builds], unique: false)
  end
end
