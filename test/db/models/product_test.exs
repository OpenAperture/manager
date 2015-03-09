defmodule DB.Models.Product.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(ProductEnvironment)
      Repo.delete_all(Product)
    end
  end

  test "product names must be unique" do
    product1 = %Product{name: "test"}
    Repo.insert(product1)

    assert_raise Postgrex.Error,
                 "ERROR (23505): duplicate key value violates unique constraint \"products_name_key\"",
                 fn -> Repo.insert(product1) end
  end

  test "product name is required" do
    product = %Product{id: 1}
    result = Product.validate(product)

    assert map_size(result) != 0
    assert Map.has_key?(result, :name)
  end

  test "retrieve associated product environments" do
    import Ecto.Query
    product = %Product{name: "test product"}
    product = Repo.insert(product)

    env1 = %ProductEnvironment{product_id: product.id, name: "test1"}
    env2 = %ProductEnvironment{product_id: product.id, name: "test2"}

    Repo.insert(env1)
    Repo.insert(env2)

    # Repo.get doesn't support preload(yet), so we need to do
    # a Repo.all call.
    [product] = Repo.all(from p in Product,
                         where: p.id == ^product.id,
                         preload: :environments)

    assert product.environments.loaded?

    assert length(product.environments.all) == 2
  end

  test "retrieve associated product environmental variables" do
    import Ecto.Query
    product = Repo.insert(%Product{name: "test product"})

    var1 = Repo.insert(%ProductEnvironmentalVariable{product_id: product.id, name: "var1", value: "value1"})
    var2 = Repo.insert(%ProductEnvironmentalVariable{product_id: product.id, name: "var2", value: "value2"})

    [product] = Repo.all(from p in Product,
                         where: p.id == ^product.id,
                         preload: :environmental_variables)

    assert product.environmental_variables.loaded?
    assert length(product.environmental_variables.all) == 2

    Repo.delete(var1)
    Repo.delete(var2)
  end
end
