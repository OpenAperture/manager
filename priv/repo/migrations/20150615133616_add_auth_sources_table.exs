defmodule OpenAperture.Manager.Repo.Migrations.AddAuthSourcesTable do
  use Ecto.Migration

  def change do
    create table(:auth_sources) do
      add :name,             :string
      add :token_info_url,   :string, null: false
      add :email_field_name, :string, null: false

      timestamps
    end

    create index(:auth_sources, [:token_info_url], unique: true)
  end
end
