defmodule ProjectOmeletteManager.Repo.Migrations.AddEtcdClustersTable do
  use Ecto.Migration

  def up do
    """
    CREATE TABLE etcd_clusters (
      id          SERIAL,
      etcd_token  varchar(140) UNIQUE NOT NULL,
      created_at  timestamp,
      updated_at  timestamp)
    """
  end

  def down do
    "DROP TABLE etcd_clusters"
  end
end
