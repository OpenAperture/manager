defmodule ProjectOmeletteManager.Repo.Migrations.AddProductDeploymentPlans do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_deployment_plans (
      id                      SERIAL PRIMARY KEY,
      product_id              integer NOT NULL REFERENCES products,
			name                    varchar(1024) NOT NULL,
      created_at              timestamp,
      updated_at              timestamp
    )
    """,
    "CREATE INDEX pdeployplans_product_idx ON product_deployment_plans(product_id)"
  ]
  end

  def down do
    ["DROP INDEX pdeployplans_product_idx",
     "DROP TABLE product_deployment_plans"]
  end
end
