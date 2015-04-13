defmodule DB.Queries.ProductEnvironmentalVariable.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.ProductEnvironmentalVariable, as: PEV
  alias OpenapertureManager.Repo
  alias OpenAperture.Manager.DB.Queries.ProductEnvironmentalVariable, as: PEVQuery
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductEnvironment

  setup_all _context do
    product = Product.new(%{name: "ProductEnvironmentalVariableQueriesTest"}) |> Repo.insert
    product2 = Product.new(%{name: "ProductEnvironmentalVariableQueriesTest2"}) |> Repo.insert
    env_testing = ProductEnvironment.new(%{product_id: product.id, name: "testing"}) |> Repo.insert
    env_staging = ProductEnvironment.new(%{product_id: product.id, name: "staging"}) |> Repo.insert

    # Set up "global" variables
    PEV.new(%{product_id: product.id, name: "A", value: "global"}) |> Repo.insert
    PEV.new(%{product_id: product.id, name: "B", value: "global"}) |> Repo.insert
    PEV.new(%{product_id: product.id, name: "C", value: "global"}) |> Repo.insert

    # Set up environment "testing" variables
    PEV.new(%{product_id: product.id, product_environment_id: env_testing.id, name: "A", value: "testing"}) |> Repo.insert
    PEV.new(%{product_id: product.id, product_environment_id: env_testing.id, name: "B", value: "testing"}) |> Repo.insert
    
    # This is a variable that is not set "globally"
    PEV.new(%{product_id: product.id, product_environment_id: env_testing.id, name: "D", value: "testing"}) |> Repo.insert

    # This is a variable that is **only** set for the "testing" environment
    PEV.new(%{product_id: product.id, product_environment_id: env_testing.id, name: "E", value: "testing"}) |> Repo.insert

    # Set up environment "staging" variables
    PEV.new(%{product_id: product.id, product_environment_id: env_staging.id, name: "A", value: "staging"}) |> Repo.insert
    PEV.new(%{product_id: product.id, product_environment_id: env_staging.id, name: "B", value: "staging"}) |> Repo.insert

    # This is a variable that is not set "globally"
    PEV.new(%{product_id: product.id, product_environment_id: env_staging.id, name: "D", value: "staging"}) |> Repo.insert

    # This is a variable that is **only** set for the "staging" environment
    PEV.new(%{product_id: product.id, product_environment_id: env_staging.id, name: "F", value: "staging"}) |> Repo.insert

    # Create some vars for product2 to verify filtering by product
    PEV.new(%{product_id: product2.id, name: "A", value: "global"}) |> Repo.insert
    PEV.new(%{product_id: product2.id, name: "B", value: "global"}) |> Repo.insert

    on_exit _context, fn ->
      Repo.delete_all(PEV)
      Repo.delete(env_testing)
      Repo.delete(env_staging)
      Repo.delete(product2)
      Repo.delete(product)
    end

    {:ok, [product: product, env_testing: env_testing, env_staging: env_staging]}
  end

  test "find by product name, environment name, and variable name", context do
    results = Repo.all(PEVQuery.find_by_product_name_environment_name_variable_name(context[:product].name, context[:env_staging].name, "A"))

    assert length(results) == 1
    [var | _] = results
    assert var.name == "A"
    assert var.value == "staging"
  end

  test "find_by_product_name_environment_name_variable_name is case-insensitive", context do
    product_name = context[:product].name |> String.upcase
    env_name = context[:env_testing].name |> String.upcase
    var_name = "a"

    result = PEVQuery.find_by_product_name_environment_name_variable_name(product_name, env_name, var_name)
             |> Repo.one

    assert result.name == "A"
    assert result.value == "testing"
  end

  test "find by product name", context do
    results = Repo.all(PEVQuery.find_by_product_name(context[:product].name))

    assert length(results) == 11
  end

  test "find_by_product_name, only product-level", context do
    product_name = context[:product].name

    results = PEVQuery.find_by_product_name(product_name, true)
              |> Repo.all

    assert length(results) == 3
  end

  test "find_by_product_name is case-insensitive", context do
    product_name = context[:product].name |> String.upcase

    results = PEVQuery.find_by_product_name(product_name)
              |> Repo.all

    assert length(results) == 11
  end

  test "find by product name and environment name", context do
    results = Repo.all(PEVQuery.find_by_product_name_environment_name(context[:product].name, context[:env_testing].name))

    assert length(results) == 4
  end

  test "find_by_product_name_environment_name is case-insensitive", context do
    product_name = context[:product].name |> String.upcase
    env_name = context[:env_testing].name |> String.upcase

    results = PEVQuery.find_by_product_name_environment_name(product_name, env_name)
              |> Repo.all
    assert length(results) == 4
  end

  test "find all for environment", context do
    results = Repo.all(PEVQuery.find_all_for_environment(context[:product].name, context[:env_testing].name))

    assert length(results) == 5

    values = Enum.map(results, fn env -> env.value end)

    assert Enum.all?(values, fn val -> val == "global" || val == "testing" end)
  end

  test "find_all_for_environment is case-insensitive", context do
    product_name = context[:product].name |> String.upcase
    env_name = context[:env_testing].name |> String.upcase

    results = PEVQuery.find_all_for_environment(product_name, env_name)
              |> Repo.all
    assert length(results) == 5
  end

  test "find by product name and variable name", context do
    results = Repo.all(PEVQuery.find_by_product_name_variable_name(context[:product].name, "A"))

    assert length(results) == 3
  end

  test "find_by_product_name_variable_name, only product_level", context do
    product_name = context[:product].name
    var_name = "A"

    results = PEVQuery.find_by_product_name_variable_name(product_name, var_name, true)
              |> Repo.all

    assert length(results) == 1
  end

  test "find_by_product_name_variable_name, only product level, won't find var with only env association", context do
    product_name = context[:product].name
    var_name = "D"

    results = PEVQuery.find_by_product_name_variable_name(product_name, var_name, true)
              |> Repo.all

    assert length(results) == 0
  end

  test "find_by_product_name_variable_name, *not* only product level, will find var with only env association", context do
    product_name = context[:product].name
    var_name = "F"

    results = PEVQuery.find_by_product_name_variable_name(product_name, var_name, false)
              |> Repo.all

    assert length(results) == 1
  end

  test "find_by_product_name_variable_name is case-insensitive", context do
    product_name = context[:product].name |> String.upcase
    var_name = "a"

    results = PEVQuery.find_by_product_name_variable_name(product_name, var_name)
              |> Repo.all

    assert length(results) == 3
  end
end