defmodule ProjectOmeletteManager.Repo.Migrations.AddProductDeploymentPlanSteps do
  use Ecto.Migration

  def up do
    ["""
    CREATE TABLE product_deployment_plan_steps (
      id                      		SERIAL PRIMARY KEY,
      product_deployment_plan_id  integer NOT NULL REFERENCES product_deployment_plans,
      on_success_step_id          integer REFERENCES product_deployment_plan_steps,
      on_failure_step_id          integer REFERENCES product_deployment_plan_steps,
			type		                    varchar(1024) NOT NULL,
      created_at		              timestamp,
      updated_at    		          timestamp
    )
    """,
    "CREATE INDEX pdeployplansteps_plan_idx ON product_deployment_plan_steps(product_deployment_plan_id)"
  ]
  end

  def down do
    ["DROP INDEX pdeployplansteps_plan_idx",
     "DROP TABLE product_deployment_plan_steps"]
  end
end
