defmodule OpenAperture.Manager.Controllers.ProductComponentsTest do
  use ExUnit.Case, async: false
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Models.EtcdClusterPort
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductComponent
  alias OpenAperture.Manager.DB.Models.ProductComponentOption
  alias OpenAperture.Manager.Router

  setup_all _context do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit _context, fn ->
      try do
        :meck.unload(OpenAperture.Manager.Plugs.Authentication)
      rescue _ -> IO.puts "" end
    end    
    :ok
  end

  setup do
    etcd_cluster = EtcdCluster.new(%{etcd_token: "test_token"})
                   |> Repo.insert

    product = Product.new(%{name: "ProductComponentTest"})
              |> Repo.insert

    product_component1 = ProductComponent.new(%{
      name: "ProductComponentTestComponent1",
      type: "web_server",
      product_id: product.id
      }) |> Repo.insert

    product_component2 = ProductComponent.new(%{
      name: "ProductComponentTestComponent2",
      type: "db",
      product_id: product.id
      }) |> Repo.insert

    product_component1_option1 = ProductComponentOption.new(%{
      name: "test",
      value: "blar",
      product_component_id: product_component1.id
      }) |> Repo.insert

    product_component1_option2 = ProductComponentOption.new(%{
      name: "test2",
      value: "ugh",
      product_component_id: product_component1.id
      }) |> Repo.insert

    ectd_cluster_port = EtcdClusterPort.new(%{
      etcd_cluster_id: etcd_cluster.id,
      product_component_id: product_component1.id,
      port: 9000
      }) |> Repo.insert

    on_exit fn ->
      Repo.delete_all(EtcdClusterPort)
      Repo.delete_all(ProductComponentOption)
      Repo.delete_all(ProductComponent)
      Repo.delete_all(EtcdCluster)
      Repo.delete_all(Product)
    end

    {:ok, 
     product: product,
     component1: product_component1,
     component2: product_component2,
     pco1: product_component1_option1,
     pco2: product_component1_option2,
     ecp: ectd_cluster_port}
  end

  test "index action -- product exists, has associated components", context do
    path = product_components_path(Endpoint, :index, context[:product].name)

    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2

    component1 = context[:component1]
    component2 = context[:component2]

    assert Enum.any?(body, fn pc ->
      pc["name"] == component1.name
      && pc["type"] == component1.type
      && length(pc["options"]) == 2
    end)

    assert Enum.any?(body, fn pc ->
      pc["name"] == component2.name
      && pc["type"] == component2.type
      && length(pc["options"]) == 0
    end)
  end

  test "index action -- product exists, no associated components" do
    product = Product.new(%{name: "ProductComponentTest2"}) |> Repo.insert
    path = product_components_path(Endpoint, :index, product.name)

    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index action -- product doesn't exist" do
    conn = call(Router, :get, "products/not_a_product_name/components")

    assert conn.status == 404
  end

  test "show action -- component exists, has associated options", context do
    product = context[:product]
    component = context[:component1]

    path = product_components_path(Endpoint, :show, product.name, component.name)

    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["name"] == component.name
    assert length(body["options"]) == 2
  end

  test "show action -- component exists, has no associated options", context do
    product = context[:product]
    component = context[:component2]

    path = product_components_path(Endpoint, :show, product.name, component.name)

    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["name"] == component.name
    assert length(body["options"]) == 0
  end

  test "show action -- component doesn't exist", context do
    product = context[:product]
    path = product_components_path(Endpoint, :show, product.name, "not a real component name")

    conn = call(Router, :get, path)

    assert conn.status == 404
  end

  test "show action -- product doesn't exist", context do
    component = context[:component1]
    path = product_components_path(Endpoint, :show, "not a real product name", component.name)
    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "create action -- product doesn't exist" do
    path = product_components_path(Endpoint, :create, "not a real product name")

    conn = call(Router, :post, path, Poison.encode!(%{name: "test_component", type: "web_server"}), [{"content-type", "application/json"}])
    assert conn.status == 404
  end

  test "create action -- component with same name already exists for product", context do
    product = context[:product]
    path = product_components_path(Endpoint, :create, product.name)

    existing_component = context[:component1]
    new_component = %{name: existing_component.name,
                  type: "web_server"}

    conn = call(Router, :post, path, Poison.encode!(new_component), [{"content-type", "application/json"}])
    assert conn.status == 409
  end

  test "create action -- invalid component type with no options", context do
    product = context[:product]
    path = product_components_path(Endpoint, :create, product.name)

    new_component = %{name: "test", type: "not a valid type"}
    
    conn = call(Router, :post, path, Poison.encode!(new_component), [{"content-type", "application/json"}])
    assert conn.status == 400

    assert conn.resp_body == "\"[type: \\\"is invalid\\\"]\""
  end

  test "create action -- invalid component name with no options", context do
    product = context[:product]
    path = product_components_path(Endpoint, :create, product.name)

    new_component = %{type: "web_server"}
    
    conn = call(Router, :post, path, Poison.encode!(new_component), [{"content-type", "application/json"}])
    assert conn.status == 400

    assert conn.resp_body == "\"[name: \\\"can't be blank\\\"]\""
  end

  test "create action -- valid component with invalid options", context do
    product = context[:product]
    path = product_components_path(Endpoint, :create, product.name)

    new_component = %{
      name: "TestComponentCreateTest",
      type: "web_server",
      options: [%{"value" => "ugh"}]}

    conn = call(Router, :post, path, Poison.encode!(new_component), [{"content-type", "application/json"}])

    assert conn.status == 400
  end

  test "create action -- valid component with no options", context do
    product = context[:product]
    path = product_components_path(Endpoint, :create, product.name)

    new_component = %{
      name: "TestComponentCreateTest",
      type: "web_server"}

    conn = call(Router, :post, path, Poison.encode!(new_component), [{"content-type", "application/json"}])

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/products/#{product.name}/components/#{new_component.name}" == location
  end

  test "create action -- valid component with valid options", context do
    product = context[:product]
    path = product_components_path(Endpoint, :create, product.name)

    new_component = %{
      name: "TestComponentCreateTest",
      type: "web_server",
      options: [%{"name" => "test", "value" => "ugh"},
                %{"name" => "test2", "value" => "ugh2"}]}

    conn = call(Router, :post, path, Poison.encode!(new_component), [{"content-type", "application/json"}])

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/products/#{product.name}/components/#{new_component.name}" == location
  end

  test "destroy action -- product not found" do
    path = product_components_path(Endpoint, :destroy, "not a real product name")

    conn = call(Router, :delete, path)
    assert conn.status == 404
  end

  test "destroy action -- success", context do
    product = context[:product]
    path = product_components_path(Endpoint, :destroy, product.name)

    conn = call(Router, :delete, path)

    assert conn.status == 204

    path = product_components_path(Endpoint, :index, product.name)
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 0
  end

  test "destroy component action -- product not found", context do
    component = context[:component1]
    path = product_components_path(Endpoint, :destroy_component, "not a real product name", component.name)

    conn = call(Router, :delete, path)

    assert conn.status == 404
  end

  test "destroy component action -- component not found", context do
    product = context[:product]
    path = product_components_path(Endpoint, :destroy_component, product.name, "not a real component name")

    conn = call(Router, :delete, path)
    assert conn.status == 404
  end

  test "destroy component action -- success", context do
    product = context[:product]
    component = context[:component1]
    path = product_components_path(Endpoint, :destroy_component, product.name, component.name)

    conn = call(Router, :delete, path)
    assert conn.status == 204

    assert nil == Repo.get(ProductComponent, component.id)
    assert nil == Repo.get(ProductComponentOption, context[:pco1].id)
    assert nil == Repo.get(ProductComponentOption, context[:pco2].id)
    assert nil == Repo.get(EtcdClusterPort, context[:ecp].id)
  end

  test "update action -- product not found", context do
    component = context[:component1]
    path = product_components_path(Endpoint, :update, "not a real product name", component.name)

    new_component = %{
      name: "TestComponentCreateTest",
      type: "web_server",
      options: [%{"name" => "test", "value" => "ugh"},
                %{"name" => "test2", "value" => "ugh2"}]}
    conn = call(Router, :put, path, Poison.encode!(new_component), [{"content-type", "application/json"}])

    assert conn.status == 404
  end

  test "update action -- component not found", context do
    product = context[:product]
    path = product_components_path(Endpoint, :update, product.name, "not a real component name")

    new_component = %{
      name: "TestComponentCreateTest",
      type: "web_server",
      options: [%{"name" => "test", "value" => "ugh"},
                %{"name" => "test2", "value" => "ugh2"}]}
    conn = call(Router, :put, path, Poison.encode!(new_component), [{"content-type", "application/json"}])

    assert conn.status == 404
  end

  test "update action -- updated component is invalid", context do
    product = context[:product]
    component = context[:component1]
    path = product_components_path(Endpoint, :update, product.name, component.name)

    new_component = %{
      name: component.name,
      type: "not a valid type",
      options: [%{"name" => "test", "value" => "ugh"},
                %{"name" => "test2", "value" => "ugh2"}]}
    conn = call(Router, :put, path, Poison.encode!(new_component), [{"content-type", "application/json"}])

    assert conn.status == 400
  end

  test "update action -- updated component has invalid option", context do
    product = context[:product]
    component = context[:component1]
    path = product_components_path(Endpoint, :update, product.name, component.name)

    new_component = %{
      name: component.name,
      type: "not a valid type",
      options: [%{"value" => "ugh"},
                %{"name" => "test2", "value" => "ugh2"}]}
    conn = call(Router, :put, path, Poison.encode!(new_component), [{"content-type", "application/json"}])

    assert conn.status == 400
  end

  test "update action -- success", context do
    product = context[:product]
    component = context[:component1]
    path = product_components_path(Endpoint, :update, product.name, component.name)

    new_component = %{
      name: component.name,
      type: "db",
      options: [%{"name" => "test", "value" => "ugh"},
                %{"name" => "test2", "value" => "ugh2"}]}
    conn = call(Router, :put, path, Poison.encode!(new_component), [{"content-type", "application/json"}])

    assert conn.status == 204
  end
end