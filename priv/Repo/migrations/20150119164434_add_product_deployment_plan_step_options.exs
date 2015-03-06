defmodule ProjectOmeletteManager.Repo.Migrations.AddProductDeploymentPlanStepOptions do
  use Ecto.Migration

  def change do
    create table(:product_deployment_plan_step_options) do
      add :product_deployment_plan_step_id, references(:product_deployment_plan_steps), null: false
      add :name, :string, null: false, size: 1024
      add :value, :text
      timestamps
    end
    create index(:product_deployment_plan_step_options, [:product_deployment_plan_step_id])
  end
end
