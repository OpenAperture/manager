defmodule OpenapertureManager.Repo.Migrations.AddProductDeploymentPlanSteps do
  use Ecto.Migration

  def change do
    create table(:product_deployment_plan_steps) do
      add :product_deployment_plan_id, references(:product_deployment_plans), null: false
      add :on_success_step_id, references(:product_deployment_plan_steps)
      add :on_failure_step_id, references(:product_deployment_plan_steps)
      add :type, :string, null: false, size: 1024
      timestamps
    end
    create index(:product_deployment_plan_steps, [:product_deployment_plan_id])
  end
end
