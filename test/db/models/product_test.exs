defmodule DB.Models.Product.Test do
  use ExUnit.Case, async: false
  import Ecto.Query

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenapertureManager.Repo
  alias OpenAperture.Manager.DB.Models.ProductEnvironment
  alias OpenAperture.Manager.DB.Models.ProductEnvironmentalVariable

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(ProductEnvironment)
      Repo.delete_all(Product)
    end
  end

  test "product names must be unique" do
    product1 = %{name: "test"}
    Product.new(product1) |> Repo.insert

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"products_name_index\"",
                 fn -> Product.new(product1) |> Repo.insert end
  end

  test "product name is required" do
    changeset = Product.new(%{id: 1})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :name)
  end

  test "product name cannot be blank" do
    changeset = Product.new(%{id: 1, name: ""})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :name)
  end

  test "product name cannot be nil" do
    changeset = Product.new(%{id: 1, name: nil})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :name)
  end

  test "retrieve associated product environments" do
    product = Product.new(%{name: "test product"}) |> Repo.insert

    _env1 = ProductEnvironment.new(%{product_id: product.id, name: "test1"}) |> Repo.insert
    _env2 = ProductEnvironment.new(%{product_id: product.id, name: "test2"}) |> Repo.insert

    # Repo.get doesn't support preload(yet), so we need to do
    # a Repo.all call.
    [product] = Repo.all(from p in Product,
                         where: p.id == ^product.id,
                         preload: :environments)

    assert length(product.environments) == 2
  end

  test "retrieve associated product environmental variables" do
    product = Product.new(%{name: "test product"}) |> Repo.insert

    var1 = ProductEnvironmentalVariable.new(%{product_id: product.id, name: "var1", value: "value1"}) |> Repo.insert
    var2 = ProductEnvironmentalVariable.new(%{product_id: product.id, name: "var2", value: "value2"}) |> Repo.insert

    [product] = Repo.all(from p in Product,
                         where: p.id == ^product.id,
                         preload: :environmental_variables)

    assert length(product.environmental_variables) == 2

    Repo.delete(var1)
    Repo.delete(var2)
  end
end
