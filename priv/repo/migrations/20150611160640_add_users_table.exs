defmodule OpenAperture.Manager.Repo.Migrations.AddUsersTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :first_name, :string, null: false
      add :last_name,  :string, null: false
      add :email,      :string, null: false

      timestamps
    end
    create index(:users, [:email], unique: true)
  end
end
