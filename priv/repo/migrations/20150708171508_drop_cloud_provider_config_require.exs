defmodule OpenAperture.Manager.Repo.Migrations.DropCloudProviderConfigRequire do
  use Ecto.Migration

  def change do
  	alter table(:cloud_providers) do
      remove :configuration
      add :configuration,     :string,                  null: true
    end
  end
end
