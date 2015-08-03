defmodule DB.Queries.ProductEnvironment.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.ProductEnvironment
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Queries.ProductEnvironment, as: ProductEnvironmentQuery
  alias OpenAperture.Manager.DB.Models.Product

  setup _context do
    product = Product.new(%{name: "ProductEnvironmentsQueriesTest"})
              |> Repo.insert!
    product2 = Product.new(%{name: "ProductEnvironmentQueryTest2"})
               |> Repo.insert!

    pe1 = ProductEnvironment.new(%{name: "env1", product_id: product2.id})
          |> Repo.insert!
    pe2 = ProductEnvironment.new(%{name: "env2", product_id: product2.id})
          |> Repo.insert!
    
    on_exit _context, fn ->
      Repo.delete_all(ProductEnvironment)
      Repo.delete!(product2)
      Repo.delete!(product)
    end

    {:ok, [product: product, product2: product2, pe1: pe1, pe2: pe2]}
  end

  test "find_by_product_name", context do
    ProductEnvironment.new(%{name: "env1", product_id: context[:product].id}) |> Repo.insert!
    ProductEnvironment.new(%{name: "env2", product_id: context[:product].id}) |> Repo.insert!
    ProductEnvironment.new(%{name: "env3", product_id: context[:product].id}) |> Repo.insert!

    results = Repo.all(ProductEnvironmentQuery.find_by_product_name(context[:product].name))

    assert length(results) == 3
  end

  test "get_environment", context do
    ProductEnvironment.new(%{name: "env1", product_id: context[:product].id}) |> Repo.insert!
    ProductEnvironment.new(%{name: "env2", product_id: context[:product].id}) |> Repo.insert!
    ProductEnvironment.new(%{name: "env3", product_id: context[:product].id}) |> Repo.insert!

    results = Repo.all(ProductEnvironmentQuery.get_environment(context[:product].name, "env2"))

    assert length(results) == 1
    assert List.first(results).name == "env2"
  end

  test "find_by_product_name performs case-insensitive search", context do
    product = context[:product2]

    name = String.upcase(product.name)

    result = name
             |> ProductEnvironmentQuery.find_by_product_name
             |> Repo.all

    assert length(result) == 2
    assert context[:pe1] in result
    assert context[:pe2] in result
  end

  test "get_environment performs case-insensitive search", context do
    product = context[:product2]
    env = context[:pe1]

    product_name = String.upcase(product.name)
    env_name = String.upcase(env.name)

    result = ProductEnvironmentQuery.get_environment(product_name, env_name)
             |> Repo.one

    assert result == env
  end
end