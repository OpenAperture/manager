defmodule ProjectOmeletteManager.Repo.Migrations.AddProductDeploymentSteps do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_deployment_steps (
      id                      				 	SERIAL PRIMARY KEY,
      product_deployment_id 					 	integer NOT NULL REFERENCES product_deployments,
      product_deployment_plan_step_id  	integer,
      product_deployment_plan_step_type varchar(1024),
      duration													varchar(1024),
      successful												boolean,
			execution_options									text,
			output														text,
			sequence											  	integer,
      created_at              					timestamp,
      updated_at              					timestamp
    )
    """,
    "CREATE INDEX pdeploysteps_deploy_idx ON product_deployment_steps(product_deployment_id)",
  ]
  end

  def down do
    ["DROP INDEX pdeploysteps_deploy_idx",
     "DROP TABLE product_deployment_steps"]
  end
end
