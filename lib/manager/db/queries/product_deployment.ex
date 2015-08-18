defmodule OpenAperture.Manager.DB.Queries.ProductDeployment do
  alias OpenAperture.Manager.DB.Models.ProductDeploymentStep
  alias OpenAperture.Manager.DB.Models.ProductDeployment
  alias OpenAperture.Manager.DB.Models.Product

  import Ecto.Query

  @doc """
  Method to retrieve the DB.Models.ProductDeploymentSteps associated with the ProductDeployment

  ## Options

  The `product_deployment_id` option is the integer identifier of the ProductDeployment
      
  ## Return values
   
  db query
  """
  @spec get_deployment_steps(term) :: term
  def get_deployment_steps(product_deployment_id) do
    from pds in ProductDeploymentStep,
    	where: pds.product_deployment_id == ^product_deployment_id,
      select: pds
  end

  @doc """
  Method to retrieve all DB.Models.ProductDeploymentSteps associated with a ProductDeployment

  ## Options

  The `product_deployment_id` option is the integer identifier of the ProductDeployment
      
  ## Return values
   
  db query
  """
  @spec get_deployments(term) :: term
  def get_deployments(product_id) do
    from pd in ProductDeployment,
      where: pd.product_id == ^product_id,
      select: pd
  end  

  def get_product_and_deployment(product_name, deployment_id) do 
    ProductDeployment
    |> join(:inner, [pd], p in Product, pd.product_id == p.id and fragment("lower(?) = lower(?)", p.name, ^product_name))
    |> where([pd, p], pd.id == ^deployment_id)
    |> select([pd, p], {p, pd})
  end 
end