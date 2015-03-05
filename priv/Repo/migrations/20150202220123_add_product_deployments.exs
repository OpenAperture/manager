defmodule ProjectOmeletteManager.Repo.Migrations.AddProductDeployments do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_deployments (
      id                      		SERIAL PRIMARY KEY,
      product_id 								  integer NOT NULL REFERENCES products,
      product_deployment_plan_id 	integer NOT NULL REFERENCES product_deployment_plans,
      product_environment_id      integer REFERENCES product_environments,
			completed										boolean,
			duration										varchar(1024),
      execution_options           text,
      output                      text,
      created_at              		timestamp,
      updated_at              		timestamp
    )
    """,
    "CREATE INDEX pdeploy_product_idx ON product_deployments(product_id)",
    "CREATE INDEX pdeploy_plan_idx ON product_deployments(product_deployment_plan_id)",
  ]
  end

  def down do
    ["DROP INDEX pdeploy_product_idx",
     "DROP INDEX pdeploy_plan_idx",
     "DROP TABLE product_deployments"]
  end
end
