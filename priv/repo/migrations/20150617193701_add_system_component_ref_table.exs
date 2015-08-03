defmodule OpenAperture.Manager.Repo.Migrations.AddSystemComponentRefTable do
  use Ecto.Migration

  def change do
  	create table(:system_component_refs) do
      add :type, :string, null: false
      add :source_repo, :string, size: 128, null: false
      add :source_repo_git_ref, :string, size: 256, null: false
      add :auto_upgrade_enabled, :boolean, null: false, default: true
      timestamps
    end

    create index(:system_component_refs, [:type], unique: false)
  end
end
