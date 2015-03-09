defmodule DB.Models.ProductComponent.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductComponent

  setup _context do
    product = Repo.insert(%Product{name: "test product"})

    product2 = Repo.insert(%Product{name: "test product2"})

    on_exit _context, fn ->
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end

    {:ok, [product: product, product2: product2]}
  end

  test "validate - fail to create component with missing values", context do
    component = %ProductComponent{}
    result    = ProductComponent.validate(component)

    assert map_size(result)    != 0
    assert result[:product_id] != nil
    assert result[:type]       != nil
    assert result[:name]       != nil
  end

  test "validate - fail to create component with missing type", context do
    component = %ProductComponent{product_id: context[:product].id, type: "crazy junk", name: "woah now"}

    result = ProductComponent.validate(component)
    assert map_size(result) != 0
    assert result[:type] != nil
  end

  test "validate - create component", context do
    component = %ProductComponent{product_id: context[:product].id, type: "web_server", name: "test component"}
    result    = ProductComponent.validate(component)

    IO.inspect(result)
    assert is_nil(result)
  end

  test "create component", context do
    component = Repo.insert(%ProductComponent{product_id: context[:product].id, type: "web_server", name: "test component"})

    retrieved = Repo.get(ProductComponent, component.id)
    assert retrieved == component
  end
end
