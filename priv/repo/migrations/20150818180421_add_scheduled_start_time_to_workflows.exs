defmodule OpenAperture.Manager.Repo.Migrations.AddScheduledStartTimeToWorkflows do
  use Ecto.Migration

  def change do
    alter table(:workflows) do
      add :scheduled_start_time, :datetime, null: true
      add :execute_options, :text, null: true
    end    
  end
end
