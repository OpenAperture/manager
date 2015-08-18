defmodule OpenAperture.Manager.DB.Queries.ProductDeploymentStep do
  alias OpenAperture.Manager.DB.Models.ProductDeploymentStep
  import Ecto.Query  

  def get_steps_of_deployment(deployment_id) do 
    from pds in ProductDeploymentStep,
      where: pds.product_deployment_id == ^deployment_id,
      select: pds
  end

  def get_step_of_deployment(deployment_id, step_id) do 
    from pds in ProductDeploymentStep,
      where: pds.product_deployment_id == ^deployment_id and pds.id == ^step_id,
      select: pds
  end 
end