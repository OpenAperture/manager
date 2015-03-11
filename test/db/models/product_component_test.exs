defmodule DB.Models.ProductComponent.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductComponent

  setup _context do
    {:ok, product} = Product.vinsert(%{name: "test product"})

    {:ok, product2} = Product.vinsert(%{name: "test product2"})

    on_exit _context, fn ->
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end

    {:ok, [product: product, product2: product2]}
  end

  test "validate - fail to create component with missing values" do
    {status, errors} = ProductComponent.vinsert(%{})
    assert status == :error
    assert Keyword.has_key?(errors, :product_id)
    assert Keyword.has_key?(errors, :type)
    assert Keyword.has_key?(errors, :name)
  end

  test "validate - fail to create component with invalid type", context do
    {status, errors} = ProductComponent.vinsert(%{product_id: context[:product].id, type: "crazy junk", name: "woah now"})
    assert status == :error
    assert Keyword.has_key?(errors, :type)
  end

  test "validate - create component", context do
    {status, _component} = ProductComponent.vinsert(%{product_id: context[:product].id, type: "web_server", name: "test component"})
    assert status == :ok
  end

  test "create component", context do
    {:ok, component} = ProductComponent.vinsert(%{product_id: context[:product].id, type: "web_server", name: "test component"})

    retrieved = Repo.get(ProductComponent, component.id)
    assert retrieved == component
  end
end
