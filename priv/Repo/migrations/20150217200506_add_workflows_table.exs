defmodule ProjectOmeletteManager.Repo.Migrations.AddWorkflowsTable do
  use Ecto.Migration

  def up do
    """
    CREATE TABLE workflows (
      id        uuid  UNIQUE  NOT NULL PRIMARY KEY,
      app_name  varchar(64)   NOT NULL,
      repo_url  varchar(128),
      branch    varchar(256),
      vendor    varchar(64),
      status    varchar(64)   NOT NULL,

      created_at timestamp,
      updated_at timestamp
    )
    """
  end

  def down do
    "DROP TABLE workflows"
  end
end
