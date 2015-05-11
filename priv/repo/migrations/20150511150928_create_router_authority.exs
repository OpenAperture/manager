defmodule OpenapertureManager.Repo.Migrations.CreateRouterAuthority do
  use Ecto.Migration

  def change do
    create table(:authorities) do
      add :hostname, :string,  null: false
      add :port,     :integer, null: false

      timestamps
    end

    create index(:authorities, ["lower(hostname)", :port], unique: true)
  end
end
