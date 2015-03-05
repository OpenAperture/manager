defmodule ProjectOmeletteManager.Repo.Migrations.AddClusterLocToClusters do
  use Ecto.Migration

  def up do
    [
      "ALTER TABLE etcd_clusters ADD hosting_provider varchar(1024)",
      "ALTER TABLE etcd_clusters ADD hosting_provider_region varchar(1024)",
    ]
  end

  def down do
    [
    	"ALTER TABLE etcd_clusters DROP COLUMN hosting_provider_region",
      "ALTER TABLE etcd_clusters DROP COLUMN hosting_provider"
    ]
  end
end
