defmodule OpenAperture.Manager.ProductEnvironmentalVariablesController.Test do
  use ExUnit.Case, async: false
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenapertureManager.Repo
  alias OpenAperture.Manager.Router

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductEnvironment
  alias OpenAperture.Manager.DB.Models.ProductEnvironmentalVariable

  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit fn -> :meck.unload end
  end

  setup do
    product = Product.new(%{name: "test_environmental_variables_product"})
              |> Repo.insert

    pe1 = ProductEnvironment.new(%{name: "test_environment_1", product_id: product.id})
          |> Repo.insert
    pe2 = ProductEnvironment.new(%{name: "test_environment_2", product_id: product.id})
          |> Repo.insert
    pev1 = ProductEnvironmentalVariable.new(%{name: "test_variable_1", product_id: product.id, product_environment_id: pe1.id})
           |> Repo.insert
    pev2 = ProductEnvironmentalVariable.new(%{name: "test_variable_2", product_id: product.id, product_environment_id: pe1.id})
           |> Repo.insert
    pev3 = ProductEnvironmentalVariable.new(%{name: "test_variable_3", product_id: product.id, product_environment_id: pe2.id})
           |> Repo.insert
    pev4 = ProductEnvironmentalVariable.new(%{name: "test_variable_4", product_id: product.id})
           |> Repo.insert

    on_exit fn ->
      Repo.delete_all(ProductEnvironmentalVariable)
      Repo.delete_all(ProductEnvironment)
      Repo.delete_all(Product)
    end

    {:ok, product: product, pe1: pe1, pe2: pe2, pev1: pev1, pev2: pev2, pev3: pev3, pev4: pev4}
  end

  test "index action (product, environment) -- success", context do
    product = context[:product]
    env = context[:pe1]

    path = product_environmental_variables_path(Endpoint, :index_environment, product.name, env.name)

    conn = call(Router, :get, path)
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 2
  end

  test "index action (product, environment) -- environment not found", context do
    product = context[:product]

    path = product_environmental_variables_path(Endpoint, :index_environment, product.name, "not a real environment name")

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "index action (product, environment) -- product not found", context do
    env = context[:pe1]

    path = product_environmental_variables_path(Endpoint, :index_environment, "not a real product name", env.name)

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "index action (product) -- success, non-coalesed", context do
    product = context[:product]

    path = product_environmental_variables_path(Endpoint, :index_default, product.name)

    conn = call(Router, :get, path)
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
  end

  test "index action (product) -- success, coalesed", context do
    product = context[:product]

    path = product_environmental_variables_path(Endpoint, :index_default, product.name, coalesced: true)

    conn = call(Router, :get, path)
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 4
  end

  test "index action (product) -- not found, non-coalesed" do
    path = product_environmental_variables_path(Endpoint, :index_default, "not a real product name")

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "index action (product) -- product not found, coalesced" do
    path = product_environmental_variables_path(Endpoint, :index_default, "not a real product name", coalesced: true)

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "show action (product, environment) -- success", context do
    product = context[:product]
    env = context[:pe1]
    var = context[:pev1]

    path = product_environmental_variables_path(Endpoint, :show_environment, product.name, env.name, var.name)

    conn = call(Router, :get, path)
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert body["name"] == var.name
    assert body["id"] == var.id
  end

  test "show action (product, environment) -- variable name not found", context do
    product = context[:product]
    env = context[:pe1]

    path = product_environmental_variables_path(Endpoint, :show_environment, product.name, env.name, "not a real variable name")

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "show action (product, environment) -- environment name not found", context do
    product = context[:product]
    var = context[:pev1]

    path = product_environmental_variables_path(Endpoint, :show_environment, product.name, "not a real environment name", var.name)

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "show action (product, environment) -- product not found", context do
    env = context[:pe1]
    var = context[:pev1]

    path = product_environmental_variables_path(Endpoint, :show_environment, "not a real product name", env.name, var.name)

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "show action (product) -- success, not coalesced", context do
    product = context[:product]
    var = context[:pev4]

    path = product_environmental_variables_path(Endpoint, :show_default, product.name, var.name)

    conn = call(Router, :get, path)
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
  end

  test "show action (product) -- success, coalesced, one variable", context do
    product = context[:product]
    var = context[:pev1]

    path = product_environmental_variables_path(Endpoint, :show_default, product.name, var.name, coalesced: true)

    conn = call(Router, :get, path)
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 1
  end

  test "show action (product) -- success, coalesced, multiple variable", context do
    product = context[:product]
    var = context[:pev1]

    _var2 = ProductEnvironmentalVariable.new(%{product_id: product.id, name: var.name})
            |> Repo.insert

    path = product_environmental_variables_path(Endpoint, :show_default, product.name, var.name, coalesced: true)
    conn = call(Router, :get, path)
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == 2
  end

  test "show action (product) -- variable name not found, not coalesced", context do
    product = context[:product]
    path = product_environmental_variables_path(Endpoint, :show_default, product.name, "not a real variable name")

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "show action (product) -- variable name not found, coalesced", context do
    product = context[:product]
    path = product_environmental_variables_path(Endpoint, :show_default, product.name, "not a real variable name", coalesced: true)

    conn = call(Router, :get, path)
    assert conn.status == 404
  end

  test "create action (product, environment) -- success", context do
    product = context[:product]
    env = context[:pe1]
    path = product_environmental_variables_path(Endpoint, :create_environment, product.name, env.name)

    new_var = %{name: "new var name"}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == "/products/#{product.name}/environments/#{env.name}/variables/#{new_var.name}"
  end

  test "create action (product, environment) -- conflict", context do
    product = context[:product]
    env = context[:pe1]
    var = context[:pev1]
    path = product_environmental_variables_path(Endpoint, :create_environment, product.name, env.name)

    new_var = %{name: var.name}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 409
  end

  test "create action (product, environment) -- missing variable name", context do
    product = context[:product]
    env = context[:pe1]
    path = product_environmental_variables_path(Endpoint, :create_environment, product.name, env.name)

    new_var = %{name: ""}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 400
  end

  test "create action (product, environment) -- environment not found", context do
    product = context[:product]
    path = product_environmental_variables_path(Endpoint, :create_environment, product.name, "not a real environment name")

    new_var = %{name: "new var name"}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 404
  end

  test "create action (product, environment) -- product not found", context do
    env = context[:pe1]
    path = product_environmental_variables_path(Endpoint, :create_environment, "not a real product name", env.name)

    new_var = %{name: "new var name"}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 404
  end

  test "create action (product) -- success", context do
    product = context[:product]
    path = product_environmental_variables_path(Endpoint, :create_default, product.name)

    new_var = %{name: "new var name"}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == "/products/#{product.name}/environmental_variables/#{new_var.name}"
  end

  test "create action (product) -- conflict", context do
    product = context[:product]
    var = context[:pev4]
    path = product_environmental_variables_path(Endpoint, :create_default, product.name)

    new_var = %{name: var.name}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 409
  end

  test "create action (product) -- missing variable name", context do
    product = context[:product]
    path = product_environmental_variables_path(Endpoint, :create_default, product.name)

    new_var = %{name: ""}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 400
  end

  test "create action (product) -- product not found" do
    path = product_environmental_variables_path(Endpoint, :create_default, "not a real product name")

    new_var = %{name: "new var name"}

    conn = call(Router, :post, path, Poison.encode!(new_var), [{"content-type", "application/json"}])
    assert conn.status == 404
  end

  test "delete action (product, environment) -- success", context do
    product = context[:product]
    env = context[:pe1]
    var = context[:pev1]

    path = product_environmental_variables_path(Endpoint, :destroy_environment, product.name, env.name, var.name)

    conn = call(Router, :delete, path)
    assert conn.status == 204
  end

  test "delete action (product, environment) -- variable name not found", context do
    product = context[:product]
    env = context[:pe1]

    path = product_environmental_variables_path(Endpoint, :destroy_environment, product.name, env.name, "not a real variable name")

    conn = call(Router, :delete, path)
    assert conn.status == 404
  end

  test "delete action (product, environment) -- environment name not found", context do
    product = context[:product]
    var = context[:pev1]

    path = product_environmental_variables_path(Endpoint, :destroy_environment, product.name, "not a real environment name", var.name)

    conn = call(Router, :delete, path)
    assert conn.status == 404
  end

  test "delete action (product, environment) -- product not found", context do
    env = context[:pe1]
    var = context[:pev1]

    path = product_environmental_variables_path(Endpoint, :destroy_environment, "not a real product name", env.name, var.name)

    conn = call(Router, :delete, path)
    assert conn.status == 404
  end

  test "delete action (product) -- success", context do
    product = context[:product]
    var = context[:pev4]

    path = product_environmental_variables_path(Endpoint, :destroy_default, product.name, var.name)

    conn = call(Router, :delete, path)
    assert conn.status == 204
  end

  test "delete action (product) -- variable name not found", context do
    product = context[:product]

    path = product_environmental_variables_path(Endpoint, :destroy_default, product.name, "not a real variable name")

    conn = call(Router, :delete, path)
    assert conn.status == 404
  end

  test "delete action (product) -- product not found", context do
    var = context[:pev4]

    path = product_environmental_variables_path(Endpoint, :destroy_default, "not a real product name", var.name)

    conn = call(Router, :delete, path)
    assert conn.status == 404
  end

  test "update action (product, environment) -- success", context do
    product = context[:product]
    env = context[:pe1]
    var = context[:pev1]
    path = product_environmental_variables_path(Endpoint, :update_environment, product.name, env.name, var.name)

    updated = %{name: "new test name", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 204

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == "/products/#{product.name}/environments/#{env.name}/variables/#{updated.name}"
  end

  test "update action (product, environment) -- conflict", context do
    product = context[:product]
    env = context[:pe1]
    var = context[:pev1]
    var2 = context[:pev2]
    path = product_environmental_variables_path(Endpoint, :update_environment, product.name, env.name, var.name)

    updated = %{name: var2.name, value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 409
  end

  test "update action (product, environment) -- invalid variable", context do
    product = context[:product]
    env = context[:pe1]
    var = context[:pev1]
    path = product_environmental_variables_path(Endpoint, :update_environment, product.name, env.name, var.name)

    updated = %{name: "", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 400
  end

  test "update action (product, environment) -- invalid variable name", context do
    product = context[:product]
    env = context[:pe1]
    path = product_environmental_variables_path(Endpoint, :update_environment, product.name, env.name, "not a real variable name")

    updated = %{name: "new test name", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 404
  end

  test "update action (product, environment) -- invalid environment name", context do
    product = context[:product]
    var = context[:pev1]
    path = product_environmental_variables_path(Endpoint, :update_environment, product.name, "not a real environment name", var.name)

    updated = %{name: "new test name", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 404
  end

  test "update action (product, environment) -- invalid product name", context do
    env = context[:pe1]
    var = context[:pev1]
    path = product_environmental_variables_path(Endpoint, :update_environment, "not a real product name", env.name, var.name)

    updated = %{name: "new test name", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 404
  end

  test "update action (product) -- success", context do
    product = context[:product]
    var = context[:pev4]
    path = product_environmental_variables_path(Endpoint, :update_default, product.name, var.name)

    updated = %{name: "new test name", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 204

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == "/products/#{product.name}/environmental_variables/#{updated.name}"
  end

  test "update action (product) -- conflict", context do
    product = context[:product]
    var = context[:pev4]
    var2 = ProductEnvironmentalVariable.new(%{name: "test_var_2", product_id: product.id})
           |> Repo.insert

    path = product_environmental_variables_path(Endpoint, :update_default, product.name, var.name)

    updated = %{name: var2.name, value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 409
  end

  test "update action (product) -- invalid variable", context do
    product = context[:product]
    var = context[:pev4]
    path = product_environmental_variables_path(Endpoint, :update_default, product.name, var.name)

    updated = %{name: "", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 400
  end

  test "update action (product) -- invalid variable name", context do
    product = context[:product]
    path = product_environmental_variables_path(Endpoint, :update_default, product.name, "not a real variable name")

    updated = %{name: "new test name", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 404
  end

  test "update action (product) -- invalid product name", context do
    var = context[:pev4]
    path = product_environmental_variables_path(Endpoint, :update_default, "not a real product name", var.name)

    updated = %{name: "new test name", value: "new test value"}

    conn = call(Router, :put, path, Poison.encode!(updated), [{"content-type", "application/json"}])
    assert conn.status == 404
  end
end