defmodule OpenAperture.Manager.Repo.Migrations.AddCloudProvidersToEtcd do
  use Ecto.Migration

  def change do
    alter table(:etcd_clusters) do
      remove :hosting_provider
      remove :hosting_provider_region
      add :hosting_provider_id, references(:cloud_providers)
    end
  end
end
