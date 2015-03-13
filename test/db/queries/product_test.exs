defmodule DB.Queries.Product.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Queries.Product, as: ProductQuery

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(Product)
    end
  end

  test "get product by name" do
    {:ok, product} = Product.vinsert(%{name: "test"})

    query = ProductQuery.get_by_name("test")
    [result] = Repo.all(query)

    assert result == product
  end

  test "get product by name with non-existant name" do
    {:ok, _product} = Product.vinsert(%{name: "test"})
    
    query = ProductQuery.get_by_name("some dumbbad name")

    assert Repo.all(query) == []
  end
end