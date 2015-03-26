defmodule DB.Queries.ProductEnvironment.Test do
  use ExUnit.Case, async: false

  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Queries.ProductEnvironment, as: ProductEnvironmentQuery
  alias ProjectOmeletteManager.DB.Models.Product

  setup _context do
    product = Product.new(%{name: "ProductEnvironmentsQueriesTest"}) |> Repo.insert
    product2 = Product.new(%{name: "ProductEnvironmentQueryTest2"}) |> Repo.insert

    ProductEnvironment.new(%{name: "env1", product_id: product2.id}) |> Repo.insert
    ProductEnvironment.new(%{name: "env2", product_id: product2.id}) |> Repo.insert
    
    on_exit _context, fn ->
      Repo.delete_all(ProductEnvironment)
      Repo.delete(product2)
      Repo.delete(product)
    end

    {:ok, [product: product]}
  end

  test "find_by_product_name", context do
    ProductEnvironment.new(%{name: "env1", product_id: context[:product].id}) |> Repo.insert
    ProductEnvironment.new(%{name: "env2", product_id: context[:product].id}) |> Repo.insert
    ProductEnvironment.new(%{name: "env3", product_id: context[:product].id}) |> Repo.insert

    results = Repo.all(ProductEnvironmentQuery.find_by_product_name(context[:product].name))

    assert length(results) == 3
  end

  test "get_environment", context do
    ProductEnvironment.new(%{name: "env1", product_id: context[:product].id}) |> Repo.insert
    ProductEnvironment.new(%{name: "env2", product_id: context[:product].id}) |> Repo.insert
    ProductEnvironment.new(%{name: "env3", product_id: context[:product].id}) |> Repo.insert

    results = Repo.all(ProductEnvironmentQuery.get_environment(context[:product].name, "env2"))

    assert length(results) == 1
    assert List.first(results).name == "env2"
  end
end