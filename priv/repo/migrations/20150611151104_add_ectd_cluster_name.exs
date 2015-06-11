defmodule OpenAperture.Manager.Repo.Migrations.AddEctdClusterName do
  use Ecto.Migration

  def change do
  	alter table(:etcd_clusters) do
  		add :name, :string
    end
  end
end
