defmodule OpenapertureManager.Repo.Migrations.AddProductDeploymentSteps do
  use Ecto.Migration

  def change do
    create table(:product_deployment_steps) do
      add :product_deployment_id, references(:product_deployments), null: false
      add :product_deployment_plan_step_id, :integer
      add :product_deployment_plan_step_type, :string, size: 1024
      add :duration, :string, size: 1024
      add :successful, :boolean
      add :execution_options, :text
      add :output, :text
      add :sequence, :integer
      timestamps
    end
    create index(:product_deployment_steps, [:product_deployment_id])
  end
end
