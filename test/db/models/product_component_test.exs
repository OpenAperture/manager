defmodule DB.Models.ProductComponent.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductComponent

  setup _context do
    product = Product.new(%{name: "test product"}) |> Repo.insert

    product2 = Product.new(%{name: "test product2"}) |> Repo.insert

    on_exit _context, fn ->
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end

    {:ok, [product: product, product2: product2]}
  end

  test "validate - fail to create component with missing values" do
    changeset = ProductComponent.new(%{})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :product_id)
    assert Keyword.has_key?(changeset.errors, :type)
    assert Keyword.has_key?(changeset.errors, :name)
  end

  test "validate - fail to create component with invalid type", context do
    changeset = ProductComponent.new(%{product_id: context[:product].id, type: "crazy junk", name: "woah now"})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :type)
  end

  test "validate - create component", context do
    changeset = ProductComponent.new(%{product_id: context[:product].id, type: "web_server", name: "test component"})
    assert changeset.valid?
  end

  test "create component", context do
    component = ProductComponent.new(%{product_id: context[:product].id, type: "web_server", name: "test component"}) |> Repo.insert

    retrieved = Repo.get(ProductComponent, component.id)
    assert retrieved == component
  end
end
