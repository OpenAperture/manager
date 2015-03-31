defmodule DB.Models.ProductEnvironmentalVariable.Test do
  use ExUnit.Case, async: false

  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable, as: PEV
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.Repo

  setup _context do
    product = Product.new(%{name: "ProductEnvironmentalVariablesModelTest"}) |> Repo.insert
    env = ProductEnvironment.new(%{product_id: product.id, name: "test environment"}) |> Repo.insert

    on_exit _context, fn ->
      Repo.delete_all(PEV)
      Repo.delete(env)
      Repo.delete(product)
    end

    {:ok, [product: product, product_environment: env]}
  end

  test "missing values fails validation" do
    changeset = PEV.new(%{})
    
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :product_id)
    assert Keyword.has_key?(changeset.errors, :name)
  end

  test "bad product_id fails insert" do
    assert_raise Postgrex.Error,
                 "ERROR (foreign_key_violation): insert or update on table \"product_environmental_variables\" violates foreign key constraint \"product_environmental_variables_product_id_fkey\"",
                 fn -> PEV.new(%{product_id: 98123784, name: "test name", value: "test value"}) |> Repo.insert end

  end

  test "bad product_environment_id fails insert", context do
    var = %{product_id: context[:product].id, product_environment_id: 92378234, name: "test name", value: "test value"}

    assert_raise Postgrex.Error,
                 "ERROR (foreign_key_violation): insert or update on table \"product_environmental_variables\" violates foreign key constraint \"product_environmental_variables_product_environment_id_fkey\"",
                 fn -> PEV.new(var) |> Repo.insert end
  end

  test "product_id, environment_id, and variable name must be unique - null environment", context do
    var = %{product_id: context[:product].id, name: "test name", value: "test value"}

    PEV.new(var) |> Repo.insert

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"pev_prod_id_name_prod_env_null_idx\"",
                 fn -> PEV.new(var) |> Repo.insert end
  end

  test "product_id, environment_id, and variable name must be unique", context do
    var = %{product_id: context[:product].id, product_environment_id: context[:product_environment].id, name: "test name", value: "test value"}

    PEV.new(var) |> Repo.insert

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"product_environmental_variables_product_id_product_environment_\"",
                 fn -> PEV.new(var) |> Repo.insert end
  end

  test "successful creation with no environment", context do
    var = %{product_id: context[:product].id, name: "Test name", value: "Test value"}

    new_env_var = PEV.new(var) |> Repo.insert

    retrieved_var = Repo.get(PEV, new_env_var.id)

    assert retrieved_var == new_env_var
    assert retrieved_var.product_id == context[:product].id
    assert retrieved_var.product_environment_id == nil
    assert retrieved_var.name == "Test name"
    assert retrieved_var.value == "Test value"
  end

  test "successful creation with an environment", context do
    new_env_var = PEV.new(%{product_id: context[:product].id, product_environment_id: context[:product_environment].id, name: "Test name", value: "Test value"}) |> Repo.insert
    retrieved_var = Repo.get(PEV, new_env_var.id)

    assert retrieved_var == new_env_var
    assert retrieved_var.product_id == context[:product].id
    assert retrieved_var.product_environment_id == context[:product_environment].id
    assert retrieved_var.name == "Test name"
    assert retrieved_var.value == "Test value"
  end

  test "validates that variable name cannot be empty, product-only variable", context do
    product = context[:product]
    changeset = PEV.new(%{product_id: product.id, name: ""})

    refute changeset.valid?

    changeset = PEV.new(%{product_id: product.id, name: "test name"})
    assert changeset.valid?
  end

  test "validates that variable name cannot be empty, product+environment variable", context do
    product = context[:product]
    env = context[:product_environment]
    changeset = PEV.new(%{product_id: product.id, product_environment_id: env.id,  name: ""})

    refute changeset.valid?

    changeset = PEV.new(%{product_id: product.id, product_environment_id: env.id, name: "test name"})
    assert changeset.valid?
  end
end
