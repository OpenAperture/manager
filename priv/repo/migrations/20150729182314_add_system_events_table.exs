defmodule OpenAperture.Manager.Repo.Migrations.AddSystemEventsTable do
  use Ecto.Migration

  def change do
    create table(:system_events) do
      add :type, :string, null: true
      add :message, :text, null: true
      add :severity, :string, null: true
      add :data, :text, null: true
      timestamps
    end
  end
end
