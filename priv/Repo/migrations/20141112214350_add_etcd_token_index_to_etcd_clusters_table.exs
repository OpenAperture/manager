defmodule ProjectOmeletteManager.Repo.Migrations.AddEtcdTokenIndexToEtcdClustersTable do
  use Ecto.Migration

  def up do
    "CREATE UNIQUE INDEX etcd_clusters_etcd_token_idx ON etcd_clusters (etcd_token)"
  end

  def down do
    "DROP INDEX etcd_clusters_etcd_token_idx"
  end
end
