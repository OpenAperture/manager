defmodule OpenAperture.Manager.Repo.Migrations.AddDismissAssigneeToEvents do
  use Ecto.Migration

  def change do
    alter table(:system_events) do
      add :dismissed_at, :datetime, null: true
      add :dismissed_by_id, references(:users), null: true
      add :dismissed_reason, :text, null: true

      add :assigned_at, :datetime, null: true
      add :assignee_id, references(:users), null: true
      add :assigned_by_id, references(:users), null: true
    end

    create index(:system_events, [:assignee_id], unique: false)
  end
end
