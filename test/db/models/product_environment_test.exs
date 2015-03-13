defmodule DB.Models.ProductEnvironment.Test do
  use ExUnit.Case

  import Ecto.Query

  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable

  setup _context do
    {:ok, product} = Product.vinsert(%{name: "ProductEnvironmentsModelsTest"})

    on_exit _context, fn ->
      Repo.delete_all(ProductEnvironment)
      Repo.delete(product)
    end

    {:ok, [product: product]}
  end

  test "missing values fail validation" do
    {status, errors} = ProductEnvironment.vinsert(%{})
    
    assert status == :error
    assert Keyword.has_key?(errors, :product_id)
    assert Keyword.has_key?(errors, :name)
  end

  test "bad product_id fails insert" do
    
    assert_raise Postgrex.Error,
                 "ERROR (foreign_key_violation): insert or update on table \"product_environments\" violates foreign key constraint \"product_environments_product_id_fkey\"",
                 fn -> ProductEnvironment.vinsert(%{product_id: 98237834, name: "test"}) end
  end

  test "product_id and environment name combo must be unique", context do
    product = context[:product]
    env_vars = %{product_id: product.id, name: "test"}
    {:ok, _env} = ProductEnvironment.vinsert(env_vars)
    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"product_environments_product_id_name_index\"",
                 fn -> ProductEnvironment.vinsert(env_vars) end
  end

  test "belongs_to Product association", context do
    product = context[:product]
    
    {:ok, pe} = ProductEnvironment.vinsert(%{product_id: product.id, name: "test"})

    assert pe.product_id == product.id
    assert pe.name == "test"
    assert pe.id > 0

    # test association loads when we preload
    # Unforunately, Repo.get doesn't support preload (yet?),
    # So we need to do a Repo.all call.
    [loaded_env] = Repo.all(from env in ProductEnvironment,
                       where: env.id == ^pe.id,
                       preload: :product)

    assert loaded_env.product == product
  end

  test "retrieve associated product environmental variables", context do
    product = context[:product]
    {:ok, product_environment} = ProductEnvironment.vinsert(%{product_id: product.id, name: "variable test"})

    {:ok, var1} = ProductEnvironmentalVariable.vinsert(%{product_id: product.id, product_environment_id: product_environment.id, name: "A", value: "test"})
    {:ok, var2} = ProductEnvironmentalVariable.vinsert(%{product_id: product.id, product_environment_id: product_environment.id, name: "B", value: "test"})

    [product_environment] = Repo.all(from pe in ProductEnvironment,
                                     where: pe.id == ^product_environment.id,
                                     preload: :environmental_variables)

    assert length(product_environment.environmental_variables) == 2

    Repo.delete(var1)
    Repo.delete(var2)
  end
end
