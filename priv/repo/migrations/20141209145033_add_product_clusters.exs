defmodule OpenapertureManager.Repo.Migrations.AddProductClusters do
  use Ecto.Migration

  def change do
    create table(:product_clusters) do
      add :product_id, references(:products), null: false
      add :etcd_cluster_id, references(:etcd_clusters)
      add :primary_ind, :boolean
      timestamps
    end
    create index(:product_clusters, [:etcd_cluster_id])
  end
end
