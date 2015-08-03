defmodule OpenAperture.Manager.Repo.Migrations.CreateRouterDeletedAuthorities do
  use Ecto.Migration

  def change do
    create table(:deleted_authorities) do
      add :hostname, :string,  null: false
      add :port,     :integer, null: false

      timestamps
    end

    create index(:deleted_authorities, [:updated_at])
  end
end
