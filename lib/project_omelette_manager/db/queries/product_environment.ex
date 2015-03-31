defmodule ProjectOmeletteManager.DB.Queries.ProductEnvironment do
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Models.Product

  import Ecto.Query

  @doc """
  Retrieve a query for the list of environments for the specified product.
  """
  @spec find_by_product_name(String.t) :: Ecto.Query.t
  def find_by_product_name(product_name) do
    from pe in ProductEnvironment,
      join: p in Product, on: pe.product_id == p.id,
      where: fragment("lower(?) = lower(?)", p.name, ^product_name),
      select: pe
  end

  @doc """
  Retrieve a query for the row with the specified product and environment.
  """
  @spec get_environment(String.t, String.t) :: Ecto.Query.t
  def get_environment(product_name, environment_name) do
    from pe in ProductEnvironment,
      join: p in Product, on: pe.product_id == p.id,
      where: fragment("lower(?) = lower(?)", p.name, ^product_name),
      where: fragment("lower(?) = lower(?)", pe.name, ^environment_name),
      select: pe
  end
end