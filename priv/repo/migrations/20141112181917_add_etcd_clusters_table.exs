defmodule OpenAperture.Manager.Repo.Migrations.AddEtcdClustersTable do
  use Ecto.Migration

  def change do
    create table(:etcd_clusters) do
      add :etcd_token, :string, null: false
      add :hosting_provider, :string, size: 1024
      add :hosting_provider_region, :string, size: 1024
      timestamps
    end
    create index(:etcd_clusters, [:etcd_token], unique: true)
  end
end
