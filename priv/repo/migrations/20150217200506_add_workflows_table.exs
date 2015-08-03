defmodule OpenAperture.Manager.Repo.Migrations.AddWorkflowsTable do
  use Ecto.Migration

  def change do
    create table(:workflows, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :deployment_repo, :string, size: 128
      add :deployment_repo_git_ref, :string, size: 256
      add :source_repo, :string, size: 128
      add :source_repo_git_ref, :string, size: 256
      add :source_commit_hash, :string, size: 256
      add :milestones, :text
      add :current_step, :string, size: 128
      add :elapsed_step_time, :string, size: 128
      add :elapsed_workflow_time, :string, size: 128
      add :workflow_duration, :string, size: 128
      add :workflow_step_durations, :text
      add :workflow_error, :boolean
      add :workflow_completed, :boolean
      add :event_log, :text
      add :app_name, :string, size: 64
      timestamps
    end
    create index(:workflows, [:deployment_repo])
  end
end
