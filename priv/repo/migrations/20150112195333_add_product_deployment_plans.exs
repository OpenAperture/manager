defmodule OpenapertureManager.Repo.Migrations.AddProductDeploymentPlans do
  use Ecto.Migration

  def change do
    create table(:product_deployment_plans) do
      add :product_id, references(:products), null: false
      add :name, :string, null: false, size: 1024
      timestamps
    end
    create index(:product_deployment_plans, [:product_id])
  end
end
