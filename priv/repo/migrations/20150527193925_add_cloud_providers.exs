defmodule OpenAperture.Manager.Repo.Migrations.AddCloudProviders do
  use Ecto.Migration

  def change do
  	create table(:cloud_providers) do
      add :name,      		  :string,                  null: false
      add :type,          	  :string,                  null: false
      add :configuration,     :string,                  null: false
      timestamps
    end
  end
end
