defmodule OpenAperture.Manager.Repo.Migrations.AddSystemComponentsTable do
  use Ecto.Migration

  def change do
  	create table(:system_components) do
  		add :messaging_exchange_id, references(:messaging_exchanges), null: false
      add :type, :string, null: false
      add :source_repo, :string, size: 128, null: false
      add :source_repo_git_ref, :string, size: 256, null: false
      add :deployment_repo, :string, size: 128
      add :deployment_repo_git_ref, :string, size: 256
      add :upgrade_strategy, :string, null: false
      timestamps
    end

    create index(:system_components, [:messaging_exchange_id, :type], unique: false)
  end
end