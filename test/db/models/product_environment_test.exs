defmodule DB.Models.ProductEnvironment.Test do
  use ExUnit.Case

  import Ecto.Query

  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable

  setup _context do
    product = Repo.insert(%Product{name: "ProductEnvironmentsModelsTest"})

    on_exit _context, fn ->
      Repo.delete_all(ProductEnvironment)
      Repo.delete(product)
    end

    {:ok, [product: product]}
  end

  test "missing product_id fails validation" do
    env = %ProductEnvironment{name: "test"}

    result = ProductEnvironment.validate(env)

    assert map_size(result) != 0
    assert result[:product_id] != nil
  end

  test "missing environment name fails validation", context do
    env    = %ProductEnvironment{product_id: context[:product].id}
    result = ProductEnvironment.validate(env)

    assert map_size(result) != 0
    assert result[:name] != nil
  end

  test "missing product_id fails insert" do
    env = %ProductEnvironment{name: "test"}

    assert_raise Postgrex.Error,
                 "ERROR (23502): null value in column \"product_id\" violates not-null constraint",
                 fn -> Repo.insert(env) end
  end

  test "missing environment name fails insert", context do
    env = %ProductEnvironment{product_id: context[:product].id}

    assert_raise Postgrex.Error,
                 "ERROR (23502): null value in column \"name\" violates not-null constraint",
                 fn -> Repo.insert(env) end
  end

  test "bad product_id fails insert" do
    env = %ProductEnvironment{product_id: 98237834, name: "test"}

    assert_raise Postgrex.Error,
                 "ERROR (23503): insert or update on table \"product_environments\" violates foreign key constraint \"product_environments_product_id_fkey\"",
                 fn -> Repo.insert(env) end
  end

  test "product_id and environment name combo must be unique", context do
    product = context[:product]
    env1 = %ProductEnvironment{product_id: product.id, name: "test"}
    env2 = %ProductEnvironment{product_id: product.id, name: "test"}

    Repo.insert(env1)

    assert_raise Postgrex.Error,
                 "ERROR (23505): duplicate key value violates unique constraint \"product_environments_product_id_name_key\"",
                 fn -> Repo.insert(env2) end
  end

  test "belongs_to Product association", context do
    product = context[:product]
    product_environment = %ProductEnvironment{product_id: product.id, name: "test"}

    pe = Repo.insert(product_environment)

    assert pe.product_id == product.id
    assert pe.name == "test"
    assert pe.id > 0

    # test association loads when we preload
    # Unforunately, Repo.get doesn't support preload (yet?),
    # So we need to do a Repo.all call.
    [loaded_env] = Repo.all(from env in ProductEnvironment,
                       where: env.id == ^pe.id,
                       preload: :product)

    assert loaded_env.product.get == product
  end

  test "retrieve associated product environmental variables", context do
    product = context[:product]
    product_environment = Repo.insert(%ProductEnvironment{product_id: product.id, name: "variable test"})

    var1 = Repo.insert(%ProductEnvironmentalVariable{product_id: product.id, product_environment_id: product_environment.id, name: "A", value: "test"})
    var2 = Repo.insert(%ProductEnvironmentalVariable{product_id: product.id, product_environment_id: product_environment.id, name: "B", value: "test"})

    [product_environment] = Repo.all(from pe in ProductEnvironment,
                                     where: pe.id == ^product_environment.id,
                                     preload: :environmental_variables)

    assert product_environment.environmental_variables.loaded?
    assert length(product_environment.environmental_variables.all) == 2

    Repo.delete(var1)
    Repo.delete(var2)
  end
end
