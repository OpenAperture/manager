defmodule OpenAperture.Manager.Repo.Migrations.AddNameFieldsToAuthSource do
  use Ecto.Migration

  def change do
    alter table(:auth_sources) do
      add :first_name_field_name, :string, null: false
      add :last_name_field_name,  :string, null: false
    end
  end
end
