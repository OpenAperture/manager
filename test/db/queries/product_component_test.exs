defmodule DB.Queries.ProductComponent.Test do
  use ExUnit.Case, async: false

  alias OpenapertureManager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductComponent
  alias OpenAperture.Manager.DB.Models.ProductComponentOption
  alias OpenAperture.Manager.DB.Queries.ProductComponent, as: PCQuery

  setup_all _context do
    on_exit _context, fn ->
      Repo.delete_all(ProductComponentOption)
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end

    #[product: product, product2: product2, cluster: etcd_cluster, etcd_cluster2: etcd_cluster2, etcd_cluster3: etcd_cluster3, etcd_cluster4: etcd_cluster4]}
    {:ok, []}
  end

  #==============================
  # get_components_for_product tests

  test "get_components_for_product- no components" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    
    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 0
  end

  test "get_components_for_product- one component with no options" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    component = ProductComponent.new(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"}) |> Repo.insert

    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 1
    returned_component = List.first(returned_components)
    assert returned_component.id == component.id
  end

  test "get_components_for_product- multiple component with no options" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    component = ProductComponent.new(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"}) |> Repo.insert
    component2 = ProductComponent.new(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"}) |> Repo.insert

    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 2

    list_results = Enum.reduce returned_components, [component.id, component2.id], fn(returned_component, remaining_components) -> 
      List.delete(remaining_components, Map.from_struct(returned_component)[:id])
    end
    assert length(list_results) == 0
  end

  test "get_components_for_product- one component with one options" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    component = ProductComponent.new(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"}) |> Repo.insert
    component_option = ProductComponentOption.new(%{product_component_id: component.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert

    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 1
    returned_component = List.first(returned_components)
    assert returned_component != nil

    list_results = Enum.reduce returned_components, [component.id], fn(raw_component, remaining_components) -> 
      returned_component = Map.from_struct(raw_component)
      assert returned_component != nil
      returned_options = raw_component.product_component_options
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
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    component = ProductComponent.new(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"}) |> Repo.insert
    component_option = ProductComponentOption.new(%{product_component_id: component.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert
    component_option2 = ProductComponentOption.new(%{product_component_id: component.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert

    component2 = ProductComponent.new(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"}) |> Repo.insert
    component_option3 = ProductComponentOption.new(%{product_component_id: component2.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert
    component_option4 = ProductComponentOption.new(%{product_component_id: component2.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert

    _product2 = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    component3 = ProductComponent.new(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"}) |> Repo.insert
    component_option5 = ProductComponentOption.new(%{product_component_id: component3.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert
    component_option6 = ProductComponentOption.new(%{product_component_id: component3.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert

    component4 = ProductComponent.new(%{product_id: product.id, name: "#{UUID.uuid1()}", type: "web_server"}) |> Repo.insert
    component_option7 = ProductComponentOption.new(%{product_component_id: component4.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert
    component_option8 = ProductComponentOption.new(%{product_component_id: component4.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert


    returned_components = Repo.all(PCQuery.get_components_for_product(product.id))
    assert length(returned_components) == 4
    returned_component = List.first(returned_components)
    assert returned_component != nil

    list_results = Enum.reduce returned_components, [component.id, component2.id, component3.id, component4.id], fn(raw_component, remaining_components) -> 
      returned_component = Map.from_struct(raw_component)
      assert returned_component != nil

      returned_options = raw_component.product_component_options
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