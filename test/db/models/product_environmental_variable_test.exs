defmodule DB.Models.ProductEnvironmentalVariable.Test do
  use ExUnit.Case

  import Ecto.Query

  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable, as: PEV
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.Repo

  setup _context do
    product = Repo.insert(%Product{name: "ProductEnvironmentalVariablesModelTest"})
    env = Repo.insert(%ProductEnvironment{product_id: product.id, name: "test environment"})

    on_exit _context, fn ->
      Repo.delete_all(PEV)
      Repo.delete(env)
      Repo.delete(product)
    end

    {:ok, [product: product, product_environment: env]}
  end

  test "missing product_id fails validation" do
    var = %PEV{name: "test name", value: "test value"}
    result = PEV.validate(var)

    assert map_size(result) != 0
    assert result[:product_id] != nil
  end

  test "missing variable name fails validation", context do
    var = %PEV{product_id: context[:product].id, value: "test value"}
    result = PEV.validate(var)

    assert map_size(result) != 0
    assert result[:name] != nil
  end

  test "missing product_id fails insert" do
    var = %PEV{name: "test name", value: "test value"}

    assert_raise Postgrex.Error,
                 "ERROR (23502): null value in column \"product_id\" violates not-null constraint",
                 fn -> Repo.insert(var) end
  end

  test "missing variable name fails insert", context do
    var = %PEV{product_id: context[:product].id, value: "test value"}

    assert_raise Postgrex.Error,
                 "ERROR (23502): null value in column \"name\" violates not-null constraint",
                 fn -> Repo.insert(var) end
  end

  test "bad product_id fails insert" do
    var = %PEV{product_id: 98123784, name: "test name", value: "test value"}

    assert_raise Postgrex.Error,
                 "ERROR (23503): insert or update on table \"product_environmental_variables\" violates foreign key constraint \"product_environmental_variables_product_id_fkey\"",
                 fn -> Repo.insert(var) end

  end

  test "bad product_environment_id fails insert", context do
    var = %PEV{product_id: context[:product].id, product_environment_id: 92378234, name: "test name", value: "test value"}

    assert_raise Postgrex.Error,
                 "ERROR (23503): insert or update on table \"product_environmental_variables\" violates foreign key constraint \"product_environmental_variables_product_environment_id_fkey\"",
                 fn -> Repo.insert(var) end
  end

  test "product_id, environment_id, and variable name must be unique - null environment", context do
    var = %PEV{product_id: context[:product].id, name: "test name", value: "test value"}

    Repo.insert(var)

    assert_raise Postgrex.Error,
                 "ERROR (23505): duplicate key value violates unique constraint \"pev_prod_id_name_prod_env_null_idx\"",
                 fn -> Repo.insert(var) end
  end

  test "product_id, environment_id, and variable name must be unique", context do
    var = %PEV{product_id: context[:product].id, product_environment_id: context[:product_environment].id, name: "test name", value: "test value"}

    Repo.insert(var)

    assert_raise Postgrex.Error,
                 "ERROR (23505): duplicate key value violates unique constraint \"pev_prod_id_prod_env_id_name_key\"",
                 fn -> Repo.insert(var) end
  end

  test "successful creation with no environment", context do
    var = %PEV{product_id: context[:product].id, name: "Test name", value: "Test value"}

    new_env_var = Repo.insert(var)

    retrieved_var = Repo.get(PEV, new_env_var.id)

    assert retrieved_var == new_env_var
    assert retrieved_var.product_id == context[:product].id
    assert retrieved_var.product_environment_id == nil
    assert retrieved_var.name == "Test name"
    assert retrieved_var.value == "Test value"
  end

  test "successful creation with an environment", context do
    var = %PEV{product_id: context[:product].id, product_environment_id: context[:product_environment].id, name: "Test name", value: "Test value"}

    new_env_var = Repo.insert(var)

    retrieved_var = Repo.get(PEV, new_env_var.id)

    assert retrieved_var == new_env_var
    assert retrieved_var.product_id == context[:product].id
    assert retrieved_var.product_environment_id == context[:product_environment].id
    assert retrieved_var.name == "Test name"
    assert retrieved_var.value == "Test value"
  end
end
