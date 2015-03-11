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
    product1 = %{name: "test"}
    Product.vinsert(product1)

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"products_name_index\"",
                 fn -> Product.vinsert(product1) end
  end

  test "product name is required" do
    {status, errors} = Product.vinsert(%{id: 1})

    assert status == :error
    assert Keyword.has_key?(errors, :name)
  end

  test "retrieve associated product environments" do
    {:ok, product} = Product.vinsert(%{name: "test product"})

    {:ok, env1} = ProductEnvironment.vinsert(%{product_id: product.id, name: "test1"})
    {:ok, env2} = ProductEnvironment.vinsert(%{product_id: product.id, name: "test2"})

    # Repo.get doesn't support preload(yet), so we need to do
    # a Repo.all call.
    [product] = Repo.all(from p in Product,
                         where: p.id == ^product.id,
                         preload: :environments)

    assert product.environments.loaded?

    assert length(product.environments.all) == 2
  end

  test "retrieve associated product environmental variables" do
    {:ok, product} = Product.vinsert(%{name: "test product"})

    {:ok, var1} = ProductEnvironmentalVariable.vinsert(%{product_id: product.id, name: "var1", value: "value1"})
    {:ok, var2} = ProductEnvironmentalVariable.vinsert(%ProductEnvironmentalVariable{product_id: product.id, name: "var2", value: "value2"})

    [product] = Repo.all(from p in Product,
                         where: p.id == ^product.id,
                         preload: :environmental_variables)

    assert product.environmental_variables.loaded?
    assert length(product.environmental_variables.all) == 2

    Repo.delete(var1)
    Repo.delete(var2)
  end
end
