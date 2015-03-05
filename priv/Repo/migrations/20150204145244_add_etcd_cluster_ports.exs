defmodule ProjectOmeletteManager.Repo.Migrations.AddEtcdClusterPorts do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE etcd_cluster_ports (
      id                      		SERIAL PRIMARY KEY,
      etcd_cluster_id 						integer NOT NULL REFERENCES etcd_clusters,
      product_component_id    		integer NOT NULL REFERENCES product_components,
      port								    		integer,
      created_at              		timestamp,
      updated_at              		timestamp
    )
    """,
    "CREATE INDEX etcdport_cluster_idx ON etcd_cluster_ports(etcd_cluster_id)",
    "CREATE INDEX etcdport_comp_idx ON etcd_cluster_ports(product_component_id)",
    "CREATE INDEX etcdport_clusterports_idx ON etcd_cluster_ports(etcd_cluster_id, port)",
  ]
  end

  def down do
    ["DROP INDEX etcdport_cluster_idx",
     "DROP INDEX etcdport_comp_idx",
     "DROP INDEX etcdport_clusterports_idx",
     "DROP TABLE etcd_cluster_ports"]
  end
end
