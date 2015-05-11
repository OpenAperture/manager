defmodule OpenAperture.Manager.Repo.Migrations.CreateRouterRoutes do
  use Ecto.Migration

  def change do
    create table(:routes) do
      add :authority_id,      references(:authorities), null: false
      add :hostname,          :string,                  null: false
      add :port,              :integer,                 null: false
      add :secure_connection, :boolean,                 null: false, default: false

      timestamps
    end

    create index(:routes, [:authority_id, "lower(hostname)", :port], unique: true)
  end
end
