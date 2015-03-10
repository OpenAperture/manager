defmodule DB.Models.ProductComponent.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductComponent

  setup _context do
    {:ok, product} = Product.vinsert(%Product{name: "test product"})

    {:ok, product2} = Product.vinsert(%Product{name: "test product2"})

    on_exit _context, fn ->
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end

    {:ok, [product: product, product2: product2]}
  end

  # test "validate - fail to create component with missing values" do
  #   {status, errors} = ProductComponent.vinsert(%ProductComponent{})
  #   assert status == :error
  #   assert Keyword.has_key?(errors, :product_id)
  #   assert Keyword.has_key?(errors, :type)
  #   assert Keyword.has_key?(errors, :name)
  # end

  test "validate - fail to create component with invalid type", context do
    component = %ProductComponent{product_id: context[:product].id, type: "crazy junk", name: "woah now"}

    {status, errors} = ProductComponent.vinsert(component)
    assert status == :error
    assert Keyword.has_key?(errors, :type)
  end

  # test "validate - create component", context do
  #   component = %ProductComponent{product_id: context[:product].id, type: "web_server", name: "test component"}
  #   result    = ProductComponent.validate(component)

  #   IO.inspect(result)
  #   assert is_nil(result)
  # end

  # test "create component", context do
  #   component = Repo.insert(%ProductComponent{product_id: context[:product].id, type: "web_server", name: "test component"})

  #   retrieved = Repo.get(ProductComponent, component.id)
  #   assert retrieved == component
  # end
end
