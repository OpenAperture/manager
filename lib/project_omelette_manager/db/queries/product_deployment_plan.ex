#
# == product_deployment_plan.ex
#
# This module contains the queries associated with ProjectOmeletteManager.DB.Models.ProductDeploymentPlan
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Queries.ProductDeploymentPlan do
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlan

  import Ecto.Query

  @doc """
  Method to retrieve the DB.Models.ProductDeploymentPlans associated with the product

  ## Options

  The `product_id` option is the integer identifier of the product
      
  ## Return values
   
  db query
  """
  @spec get_deployment_plans_for_product(term) :: term
  def get_deployment_plans_for_product(product_id) do
    from pdp in ProductDeploymentPlan,
    	where: pdp.product_id == ^product_id,
      select: pdp
  end

  @doc """
  Method to retrieve the DB.Models.ProductDeploymentPlan by product and name

  ## Options

  The `product_id` option is the integer identifier of the product

  The `plan_name` option is the string name of the product
      
  ## Return values
   
  db query
  """
  @spec get_deployment_plan_by_name(term, String.t()) :: term
  def get_deployment_plan_by_name(product_id, plan_name) do
    from pdp in ProductDeploymentPlan,
      where: pdp.product_id == ^product_id and pdp.name == ^plan_name,
      select: pdp
  end   
end