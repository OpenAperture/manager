#
# == product_component.ex
#
# This module contains the queries associated with ProjectOmeletteManager.DB.Models.ProductComponent
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Queries.ProductComponent do
  alias ProjectOmeletteManager.DB.Models.ProductComponent

  import Ecto.Query

  @doc """
  Method to retrieve the DB.Models.ProductComponents associated with the product

  ## Options

  The `product_id` option is the integer identifier of the product
      
  ## Return values
   
  db query
  """
  @spec get_components_for_product(term) :: term
  def get_components_for_product(product_id) do
    from pc in ProductComponent,
    	where: pc.product_id == ^product_id,
    	left_join: pco in assoc(pc, :product_component_options),
      preload: [product_component_options: pco]
  end

  @doc """
  Method to retrieve the DB.Models.ProductComponent by product and name

  ## Options

  The `product_id` option is the integer identifier of the product

  The `component_name` option is the string name of the product
      
  ## Return values
   
  db query
  """
  @spec get_component_by_name(term, String.t()) :: term
  def get_component_by_name(product_id, component_name) do
    from pc in ProductComponent,
      where: pc.product_id == ^product_id and pc.name == ^component_name,
      left_join: pco in assoc(pc, :product_component_options),
      preload: [product_component_options: pco]
  end  
end