defmodule ProjectOmeletteManager.Repo.Migrations.AddProductClusters do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_clusters (
      id                      SERIAL PRIMARY KEY,
      product_id              integer NOT NULL REFERENCES products,
      etcd_cluster_id         integer REFERENCES etcd_clusters,
      created_at              timestamp,
      updated_at              timestamp
    )
    """,
    "CREATE INDEX pc_cluster_idx ON product_clusters(etcd_cluster_id)"
  ]
  end

  def down do
    ["DROP INDEX pc_cluster_idx",
     "DROP TABLE product_clusters"]
  end
end
