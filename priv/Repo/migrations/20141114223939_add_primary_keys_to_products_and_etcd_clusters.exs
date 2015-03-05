defmodule ProjectOmeletteManager.Repo.Migrations.AddPrimaryKeysToProductsAndEtcdClusters do
  use Ecto.Migration

  def up do
    ["ALTER TABLE products ADD PRIMARY KEY (id)",
     "ALTER TABLE etcd_clusters ADD PRIMARY KEY (id)"]
  end

  def down do
    ["ALTER TABLE products DROP CONSTRAINT products_pkey",
     "ALTER TABLE etcd_clusters DROP CONSTRAINT etcd_clusters_pkey"]
  end
end
