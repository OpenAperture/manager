defmodule ProjectOmeletteManager.DB.Queries.ProductEnvironmentalVariable do
  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Models.Product

  import Ecto.Query

  @doc """
  Retrieve a query that will fetch a list of a single row with the 
  environmental variable matching the product, product_environment, and name
  provided. This query uses joins between the products, product_environments,
  and product_environmental_variables tables to find the correct row.
  """
  @spec find_by_product_name_environment_name_variable_name(String.t, String.t, String.t) :: Ecto.Query.t
  def find_by_product_name_environment_name_variable_name(product_name, environment_name, name) do
    from pev in ProductEnvironmentalVariable,
      join: p in Product, on: pev.product_id == p.id,
      join: pe in ProductEnvironment, on: pev.product_environment_id == pe.id,
      where: p.name == ^product_name and pe.name == ^environment_name and pev.name == ^name,
      select: pev
  end

  @spec find_by_product_name(String.t) :: Ecto.Query.t
  def find_by_product_name(product_name) do
    from pev in ProductEnvironmentalVariable,
      join: p in Product, on: pev.product_id == p.id,
      where: p.name == ^product_name,
      select: pev
  end

  @spec find_by_product_name_environment_name(String.t, String.t) :: Ecto.Query.t
  def find_by_product_name_environment_name(product_name, environment_name) do
    from pev in ProductEnvironmentalVariable,
      join: p in Product, on: pev.product_id == p.id,
      join: pe in ProductEnvironment, on: pev.product_environment_id == pe.id,
      where: p.name == ^product_name and pe.name == ^environment_name,
      select: pev
  end

  @spec find_by_product_name_variable_name(String.t, String.t) :: Ecto.Query.t
  def find_by_product_name_variable_name(product_name, variable_name) do
    from pev in ProductEnvironmentalVariable,
      join: p in Product, on: pev.product_id == p.id,
      where: pev.name == ^variable_name and p.name == ^product_name,
      select: pev
  end

  @doc """
  Retrieve a query that coalesces the collection of environmental variables
  for a product, overriding product-wide values with any environment-specific
  settings. For example, if a product has two variables:
  A = 1
  B = 2
  but the products "production" environment has the variable
  B = 23
  calling this query with the ID of the "production" environment will
  return a list with variables
  A = 1
  B = 23
  """
  @spec find_all_for_environment(String.t, String.t) :: Ecto.Query.t
  def find_all_for_environment(product_name, environment_name) do
    from pev in ProductEnvironmentalVariable,
      join: p in Product, on: pev.product_id == p.id,
      left_join: pe in ProductEnvironment, on: pev.product_environment_id == pe.id,
      distinct: pev.name,
      order_by: [pev.name, pev.product_environment_id],
      where: p.name == ^product_name,
      where: pe.name == ^environment_name or is_nil(pev.product_environment_id),
      select: pev
  end
end