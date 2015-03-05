defmodule ProjectOmeletteManager.Repo.Migrations.AddProductDeploymentPlanStepOptions do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_deployment_plan_step_options (
      id                      						SERIAL PRIMARY KEY,
      product_deployment_plan_step_id    	integer NOT NULL REFERENCES product_deployment_plan_steps,
      name                    						varchar(1024) NOT NULL,
      value                   						text,
      created_at              						timestamp,
      updated_at              						timestamp
    )
    """,
    "CREATE INDEX pdeployplanstepopts_step_idx ON product_deployment_plan_step_options(product_deployment_plan_step_id)"
  ]
  end

  def down do
    ["DROP INDEX pdeployplanstepopts_step_idx",
     "DROP TABLE product_deployment_plan_step_options"]
  end
end
