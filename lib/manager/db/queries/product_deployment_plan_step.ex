defmodule OpenAperture.Manager.DB.Queries.ProductDeploymentPlanStep do
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStepOption

  import Ecto.Query

  @doc """
  Method to retrieve the DB.Models.ProductDeploymentPlans associated with the ProductDeploymentPlan

  ## Options

  The `product_id` option is the integer identifier of the ProductDeploymentPlan
      
  ## Return values
   
  db query
  """
  @spec get_steps_for_plan(term) :: term
  def get_steps_for_plan(product_deployment_plan_id) do
    from pdps in ProductDeploymentPlanStep,
    	where: pdps.product_deployment_plan_id == ^product_deployment_plan_id,
      left_join: pspso in assoc(pdps, :product_deployment_plan_step_options),
      preload: [product_deployment_plan_step_options: pspso]
  end

  @doc """
  Method to retrieve the DB.Models.ProductDeploymentPlanStepOptions associated with the ProductDeploymentPlanStep

  ## Options

  The `step_id` option is the integer identifier of the ProductDeploymentPlanStep
      
  ## Return values
   
  db query
  """
  @spec get_options_for_step(term) :: term
  def get_options_for_step(step_id) do
    from pdpso in ProductDeploymentPlanStepOption,
      where: pdpso.product_deployment_plan_step_id == ^step_id,
      select: pdpso
  end

  def get_parent_step(child_step_id) do 
    from pdps in ProductDeploymentPlanStep,
    where: pdps.on_success_step_id == ^child_step_id or pdps.on_failure_step_id == ^child_step_id,
    select: pdps
  end

end