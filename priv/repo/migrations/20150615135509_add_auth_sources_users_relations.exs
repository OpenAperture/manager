defmodule OpenAperture.Manager.Repo.Migrations.AddAuthSourcesUsersRelations do
  use Ecto.Migration

  def change do
    create table(:auth_sources_users_relations) do
      add :auth_source_id, references(:auth_sources)
      add :user_id,        references(:users)

      timestamps
    end

    create index(:auth_sources_users_relations, [:auth_source_id, :user_id], unique: true)
  end
end
