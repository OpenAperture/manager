defmodule DB.Queries.ProductComponent.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductComponent
  alias ProjectOmeletteManager.DB.Models.ProductComponentOption
  alias ProjectOmeletteManager.DB.Queries.ProductComponent, as: PCQuery

  setup_all _context do
    on_exit _context, fn ->
      Repo.delete_all(ProductComponentOption)
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end

    #{:ok, [product: product, product2: product2, cluster: etcd_cluster, etcd_cluster2: etcd_cluster2, etcd_cluster3: etcd_cluster3, etcd_cluster4: etcd_cluster4]}
    {:ok, []}
  end

  #==============================
  # get_components_for_product tests

  test "get_components_for_product- no components" do
    {:ok, product} = Product.vinsert(%{name: "#{UUID.uuid1()}"})
    
    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 0
  end

  test "get_components_for_product- one component with no options" do
    {:ok, product} = Product.vinsert(%{name: "#{UUID.uuid1()}"})
    {:ok, component} = ProductComponent.vinsert(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"})

    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 1
    returned_component = hd(returned_components)
    assert returned_component.id == component.id
  end

  test "get_components_for_product- multiple component with no options" do
    {:ok, product} = Product.vinsert(%{name: "#{UUID.uuid1()}"})
    {:ok, component} = ProductComponent.vinsert(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"})
    {:ok, component2} = ProductComponent.vinsert(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"})

    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 2

    list_results = Enum.reduce returned_components, [component.id, component2.id], fn(returned_component, remaining_components) -> 
      List.delete(remaining_components, Map.from_struct(returned_component)[:id])
    end
    assert length(list_results) == 0
  end

  test "get_components_for_product- one component with one options" do
    {:ok, product} = Product.vinsert(%{name: "#{UUID.uuid1()}"})
    {:ok, component} = ProductComponent.vinsert(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"})
    {:ok, component_option} = ProductComponentOption.vinsert(%{product_component_id: component.id, name: "#{UUID.uuid1()}", value: "something cool"})

    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 1
    returned_component = hd(returned_components)
    assert returned_component != nil

    list_results = Enum.reduce returned_components, [component.id], fn(raw_component, remaining_components) -> 
      returned_component = Map.from_struct(raw_component)
      assert returned_component != nil

      returned_options = raw_component.product_component_options.all
      assert returned_options != nil

      if (returned_component[:id] == component.id) do
        options_results = Enum.reduce returned_options, [component_option.id], fn(raw_option, remaining_components) -> 
          List.delete(remaining_components, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0        
      end
      List.delete(remaining_components, returned_component[:id])
    end
    assert length(list_results) == 0
  end

  test "get_components_for_product- multiple component with multiple options" do
    {:ok, product} = Product.vinsert(%{name: "#{UUID.uuid1()}"})
    {:ok, component} = ProductComponent.vinsert(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"})
    {:ok, component_option} = ProductComponentOption.vinsert(%{product_component_id: component.id, name: "#{UUID.uuid1()}", value: "something cool"})
    {:ok, component_option2} = ProductComponentOption.vinsert(%{product_component_id: component.id, name: "#{UUID.uuid1()}", value: "something cool"})

    {:ok, component2} = ProductComponent.vinsert(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"})
    {:ok, component_option3} = ProductComponentOption.vinsert(%{product_component_id: component2.id, name: "#{UUID.uuid1()}", value: "something cool"})
    {:ok, component_option4} = ProductComponentOption.vinsert(%{product_component_id: component2.id, name: "#{UUID.uuid1()}", value: "something cool"})

    {:ok, _product2} = Product.vinsert(%{name: "#{UUID.uuid1()}"})
    {:ok, component3} = ProductComponent.vinsert(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"})
    {:ok, component_option5} = ProductComponentOption.vinsert(%{product_component_id: component3.id, name: "#{UUID.uuid1()}", value: "something cool"})
    {:ok, component_option6} = ProductComponentOption.vinsert(%{product_component_id: component3.id, name: "#{UUID.uuid1()}", value: "something cool"})

    {:ok, component4} = ProductComponent.vinsert(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"})
    {:ok, component_option7} = ProductComponentOption.vinsert(%{product_component_id: component4.id, name: "#{UUID.uuid1()}", value: "something cool"})
    {:ok, component_option8} = ProductComponentOption.vinsert(%{product_component_id: component4.id, name: "#{UUID.uuid1()}", value: "something cool"})


    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 4
    returned_component = hd(returned_components)
    assert returned_component != nil

    list_results = Enum.reduce returned_components, [component.id, component2.id, component3.id, component4.id], fn(raw_component, remaining_components) -> 
      returned_component = Map.from_struct(raw_component)
      assert returned_component != nil

      returned_options = raw_component.product_component_options.all
      assert returned_options != nil

      if (returned_component[:id] == component.id) do
        options_results = Enum.reduce returned_options, [component_option.id, component_option2.id], fn(raw_option, remaining_components) -> 
          List.delete(remaining_components, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0        
      end

      if (returned_component[:id] == component2.id) do
        options_results = Enum.reduce returned_options, [component_option3.id, component_option4.id], fn(raw_option, remaining_components) -> 
          List.delete(remaining_components, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0        
      end

      if (returned_component[:id] == component3.id) do
        options_results = Enum.reduce returned_options, [component_option5.id, component_option6.id], fn(raw_option, remaining_components) -> 
          List.delete(remaining_components, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0        
      end

      if (returned_component[:id] == component4.id) do
        options_results = Enum.reduce returned_options, [component_option7.id, component_option8.id], fn(raw_option, remaining_components) -> 
          List.delete(remaining_components, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0        
      end

      List.delete(remaining_components, returned_component[:id])
    end
    assert length(list_results) == 0
  end  
end