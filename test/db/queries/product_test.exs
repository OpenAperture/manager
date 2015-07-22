defmodule DB.Queries.Product.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Queries.Product, as: ProductQuery

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(Product)
    end
  end

  test "get product by name" do
    product = Product.new(%{name: "test"}) |> Repo.insert!

    query = ProductQuery.get_by_name("test")
    [result] = Repo.all(query)

    assert result == product
  end

  test "get product by name with non-existant name" do
    _product = Product.new(%{name: "test"}) |> Repo.insert!
    
    query = ProductQuery.get_by_name("some dumbbad name")

    assert Repo.all(query) == []
  end
end