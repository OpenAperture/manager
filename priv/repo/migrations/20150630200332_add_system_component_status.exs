defmodule OpenAperture.Manager.Repo.Migrations.AddSystemComponentStatus do
  use Ecto.Migration

  def change do
  	alter table(:system_components) do
  		add :status, :string, null: true
  		add :upgrade_status, :text, null: true
    end
  end
end
