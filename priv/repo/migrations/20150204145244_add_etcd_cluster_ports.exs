defmodule OpenapertureManager.Repo.Migrations.AddEtcdClusterPorts do
  use Ecto.Migration

  def change do
    create table(:etcd_cluster_ports) do
      add :etcd_cluster_id, references(:etcd_clusters), null: false
      add :product_component_id, references(:product_components), null: false
      add :port, :integer
      timestamps
    end
    create index(:etcd_cluster_ports, [:etcd_cluster_id])
    create index(:etcd_cluster_ports, [:product_component_id])
    create index(:etcd_cluster_ports, [:etcd_cluster_id, :port])
  end
end
