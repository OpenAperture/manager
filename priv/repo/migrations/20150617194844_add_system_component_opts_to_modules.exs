defmodule OpenAperture.Manager.Repo.Migrations.AddSystemComponentOptsToModules do
  use Ecto.Migration

  def change do
    alter table(:messaging_exchange_modules) do
      add :source_repo, :string, size: 128, null: true
      add :source_repo_git_ref, :string, size: 256, null: true
      add :deployment_repo, :string, size: 128, null: true
      add :deployment_repo_git_ref, :string, size: 256, null: true  
    end  	
  end
end
