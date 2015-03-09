defmodule DB.Queries.ProductEnvironmentalVariable.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable, as: PEV
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Queries.ProductEnvironmentalVariable, as: PEVQuery
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment

  setup_all _context do
    product = Repo.insert(%Product{name: "ProductEnvironmentalVariableQueriesTest"})
    product2 = Repo.insert(%Product{name: "ProductEnvironmentalVariableQueriesTest2"})
    env_testing = Repo.insert(%ProductEnvironment{product_id: product.id, name: "testing"})
    env_staging = Repo.insert(%ProductEnvironment{product_id: product.id, name: "staging"})

    # Set up "global" variables
    Repo.insert(%PEV{product_id: product.id, name: "A", value: "global"})
    Repo.insert(%PEV{product_id: product.id, name: "B", value: "global"})
    Repo.insert(%PEV{product_id: product.id, name: "C", value: "global"})

    # Set up environment "testing" variables
    Repo.insert(%PEV{product_id: product.id, product_environment_id: env_testing.id, name: "A", value: "testing"})
    Repo.insert(%PEV{product_id: product.id, product_environment_id: env_testing.id, name: "B", value: "testing"})
    
    # This is a variable that is not set "globally"
    Repo.insert(%PEV{product_id: product.id, product_environment_id: env_testing.id, name: "D", value: "testing"})

    # This is a variable that is **only** set for the "testing" environment
    Repo.insert(%PEV{product_id: product.id, product_environment_id: env_testing.id, name: "E", value: "testing"})

    # Set up environment "staging" variables
    Repo.insert(%PEV{product_id: product.id, product_environment_id: env_staging.id, name: "A", value: "staging"})
    Repo.insert(%PEV{product_id: product.id, product_environment_id: env_staging.id, name: "B", value: "staging"})

    # This is a variable that is not set "globally"
    Repo.insert(%PEV{product_id: product.id, product_environment_id: env_staging.id, name: "D", value: "staging"})

    # This is a variable that is **only** set for the "staging" environment
    Repo.insert(%PEV{product_id: product.id, product_environment_id: env_staging.id, name: "F", value: "staging"})

    # Create some vars for product2 to verify filtering by product
    Repo.insert(%PEV{product_id: product2.id, name: "A", value: "global"})
    Repo.insert(%PEV{product_id: product2.id, name: "B", value: "global"})

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

  test "find by product name", context do
    results = Repo.all(PEVQuery.find_by_product_name(context[:product].name))

    assert length(results) == 11
  end

  test "find by product name and environment name", context do
    results = Repo.all(PEVQuery.find_by_product_name_environment_name(context[:product].name, context[:env_testing].name))

    assert length(results) == 4
  end

  test "find all for environment", context do
    results = Repo.all(PEVQuery.find_all_for_environment(context[:product].name, context[:env_testing].name))

    assert length(results) == 5

    values = Enum.map(results, fn env -> env.value end)

    assert Enum.all?(values, fn val -> val == "global" || val == "testing" end)
  end

  test "find by product name and variable name", context do
    results = Repo.all(PEVQuery.find_by_product_name_variable_name(context[:product].name, "A"))

    assert length(results) == 3

    values = Enum
  end
end