defmodule DB.Models.ProductEnvironmentalVariable.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable, as: PEV
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.Repo

  setup _context do
    {:ok, product} = Product.vinsert(%{name: "ProductEnvironmentalVariablesModelTest"})
    {:ok, env} = ProductEnvironment.vinsert(%{product_id: product.id, name: "test environment"})

    on_exit _context, fn ->
      Repo.delete_all(PEV)
      Repo.delete(env)
      Repo.delete(product)
    end

    {:ok, [product: product, product_environment: env]}
  end

  test "missing values fails validation" do
    {status, errors} = PEV.vinsert(%{})
    
    assert status == :error
    assert Keyword.has_key?(errors, :product_id)
    assert Keyword.has_key?(errors, :name)
  end

  test "bad product_id fails insert" do
    assert_raise Postgrex.Error,
                 "ERROR (foreign_key_violation): insert or update on table \"product_environmental_variables\" violates foreign key constraint \"product_environmental_variables_product_id_fkey\"",
                 fn -> PEV.vinsert(%{product_id: 98123784, name: "test name", value: "test value"}) end

  end

  test "bad product_environment_id fails insert", context do
    var = %{product_id: context[:product].id, product_environment_id: 92378234, name: "test name", value: "test value"}

    assert_raise Postgrex.Error,
                 "ERROR (23503): insert or update on table \"product_environmental_variables\" violates foreign key constraint \"product_environmental_variables_product_environment_id_fkey\"",
                 fn -> PEV.vinsert(var) end
  end

  test "product_id, environment_id, and variable name must be unique - null environment", context do
    var = %{product_id: context[:product].id, name: "test name", value: "test value"}

    PEV.vinsert(var)

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"pev_prod_id_name_prod_env_null_idx\"",
                 fn -> PEV.vinsert(var) end
  end

  test "product_id, environment_id, and variable name must be unique", context do
    var = %{product_id: context[:product].id, product_environment_id: context[:product_environment].id, name: "test name", value: "test value"}

    PEV.vinsert(var)

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"pev_prod_id_name_prod_env_null_idx\"",
                 fn -> PEV.vinsert(var) end
  end

  test "successful creation with no environment", context do
    var = %{product_id: context[:product].id, name: "Test name", value: "Test value"}

    {:ok, new_env_var} = PEV.vinsert(var)

    retrieved_var = Repo.get(PEV, new_env_var.id)

    assert retrieved_var == new_env_var
    assert retrieved_var.product_id == context[:product].id
    assert retrieved_var.product_environment_id == nil
    assert retrieved_var.name == "Test name"
    assert retrieved_var.value == "Test value"
  end

  test "successful creation with an environment", context do
    var = %{product_id: context[:product].id, product_environment_id: context[:product_environment].id, name: "Test name", value: "Test value"}

    {:ok, new_env_var} = PEV.vinsert(var)

    retrieved_var = Repo.get(PEV, new_env_var.id)

    assert retrieved_var == new_env_var
    assert retrieved_var.product_id == context[:product].id
    assert retrieved_var.product_environment_id == context[:product_environment].id
    assert retrieved_var.name == "Test name"
    assert retrieved_var.value == "Test value"
  end
end
