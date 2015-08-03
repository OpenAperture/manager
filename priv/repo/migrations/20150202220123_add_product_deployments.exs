defmodule OpenAperture.Manager.Repo.Migrations.AddProductDeployments do
  use Ecto.Migration

  def change do
    create table(:product_deployments) do
      add :product_id, references(:products), null: false
      add :product_deployment_plan_id, references(:product_deployment_plans), null: false
      add :product_environment_id, references(:product_environments)
      add :completed, :boolean
      add :duration, :string, size: 1024
      add :execution_options, :text
      add :output, :text
      timestamps
    end
    create index(:product_deployments, [:product_id])
    create index(:product_deployments, [:product_deployment_plan_id])
  end
end
