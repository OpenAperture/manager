defmodule ProjectOmeletteManager.Repo.Migrations.UpdateWorkflowStatusTable do
  use Ecto.Migration

  def up do
  	[
    	"ALTER TABLE workflows DROP COLUMN vendor",
    	"ALTER TABLE workflows DROP COLUMN app_name",
    	"ALTER TABLE workflows DROP COLUMN repo_url",
    	"ALTER TABLE workflows DROP COLUMN status",
    	"ALTER TABLE workflows DROP COLUMN branch",
    	"ALTER TABLE workflows ADD deployment_repo varchar(128)",
    	"ALTER TABLE workflows ADD deployment_repo_git_ref varchar(256)",
			"ALTER TABLE workflows ADD source_repo varchar(128)",
    	"ALTER TABLE workflows ADD source_repo_git_ref varchar(256)",
    	"ALTER TABLE workflows ADD source_commit_hash varchar(256)",
    	"ALTER TABLE workflows ADD milestones text",
    	"ALTER TABLE workflows ADD current_step varchar(128)",
    	"ALTER TABLE workflows ADD elapsed_step_time varchar(128)",    	
    	"ALTER TABLE workflows ADD elapsed_workflow_time varchar(128)",    	
    	"ALTER TABLE workflows ADD workflow_duration varchar(128)",    	
    	"ALTER TABLE workflows ADD workflow_step_durations text",
    	"ALTER TABLE workflows ADD workflow_error boolean",
    	"ALTER TABLE workflows ADD workflow_completed boolean",    	
			"ALTER TABLE workflows ADD event_log text",
      "CREATE INDEX workflow_deployment_repo_idx ON workflows(deployment_repo)"
    ]
  end

  def down do
  	[
      "ALTER TABLE workflows ADD branch varchar(256)",
  		"ALTER TABLE workflows ADD status varchar(64)",
    	"ALTER TABLE workflows ADD vendor varchar(64)",
			"ALTER TABLE workflows ADD app_name varchar(64)",    	
    	"ALTER TABLE workflows ADD repo_url varchar(128)",
      "DROP INDEX workflow_deployment_repo_idx",
    	"ALTER TABLE workflows DROP COLUMN deployment_repo",
    	"ALTER TABLE workflows DROP COLUMN deployment_repo_git_ref",
    	"ALTER TABLE workflows DROP COLUMN source_repo",
    	"ALTER TABLE workflows DROP COLUMN source_repo_git_ref",    	
    	"ALTER TABLE workflows DROP COLUMN source_commit_hash",
    	"ALTER TABLE workflows DROP COLUMN milestones",
    	"ALTER TABLE workflows DROP COLUMN current_step",
    	"ALTER TABLE workflows DROP COLUMN elapsed_step_time",
    	"ALTER TABLE workflows DROP COLUMN elapsed_workflow_time",
    	"ALTER TABLE workflows DROP COLUMN workflow_duration",
    	"ALTER TABLE workflows DROP COLUMN workflow_step_durations",
    	"ALTER TABLE workflows DROP COLUMN workflow_error",
    	"ALTER TABLE workflows DROP COLUMN workflow_completed",
    	"ALTER TABLE workflows DROP COLUMN event_log"
  	]
  end
end
