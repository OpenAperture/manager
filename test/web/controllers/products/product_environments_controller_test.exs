defmodule ProjectOmeletteManager.ProductEnvironmentsController.Test do
  use ExUnit.Case, async: false
  use Plug.Test
  use ProjectOmeletteManager.Test.ConnHelper

  import ProjectOmeletteManager.Router.Helpers

  alias ProjectOmeletteManager.Endpoint
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.Router

  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable
  
  setup_all do
    :meck.new(ProjectOmeletteManager.Plugs.Authentication, [:passthrough])
    :meck.expect(ProjectOmeletteManager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit fn -> :meck.unload end
  end

  setup do
    product = Product.new(%{name: "test_environments_product"})
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

  test "index action -- success", context do
    product = context[:product]

    path = product_environments_path(Endpoint, :index, product.name)

    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2
  end

  test "index action -- product exists, but no environments" do
    product = Product.new(%{name: "test_environments_product_2"})
              |> Repo.insert

    path = product_environments_path(Endpoint, :index, product.name)

    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index action -- product does not exist" do
    path = product_environments_path(Endpoint, :index, "not a real product name")

    conn = call(Router, :get, path)

    assert conn.status == 404
  end

  test "show action -- success", context do
    product = context[:product]
    env = context[:pe1]

    path = product_environments_path(Endpoint, :show, product.name, env.name)

    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert env.name == body["name"]
    assert env.product_id == body["product_id"]
  end

  test "show action -- environment doesn't exist", context do
    product = context[:product]

    path = product_environments_path(Endpoint, :show, product.name, "not a real environment name")

    conn = call(Router, :get, path)

    assert conn.status == 404
  end

  test "show action -- product doesn't exist", context do
    env = context[:pe1]

    path = product_environments_path(Endpoint, :show, "not a real product name", env.name)

    conn = call(Router, :get, path)

    assert conn.status == 404
  end

  test "create action -- success", context do
    product = context[:product]

    num_environments = length(Repo.all(ProductEnvironment))

    new_env = %{name: "new_test_product_environment"}

    path = product_environments_path(Endpoint, :create, product.name)

    conn = call(Router, :post, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/products/#{product.name}/environments/#{new_env.name}" == location

    assert num_environments + 1 == length(Repo.all(ProductEnvironment))
  end

  test "create action -- environment name already exists", context do
    product = context[:product]
    env = context[:pe1]

    num_environments = length(Repo.all(ProductEnvironment))

    new_env = %{name: env.name}

    path = product_environments_path(Endpoint, :create, product.name)

    conn = call(Router, :post, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 409

    assert num_environments == length(Repo.all(ProductEnvironment))
  end

  test "create action -- fails if missing environment name param", context do
    product = context[:product]

    num_environments = length(Repo.all(ProductEnvironment))

    new_env = %{}

    path = product_environments_path(Endpoint, :create, product.name)

    conn = call(Router, :post, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 400

    assert num_environments == length(Repo.all(ProductEnvironment))
  end

  test "create action -- fails if environment name param is invalid", context do
    product = context[:product]

    num_environments = length(Repo.all(ProductEnvironment))

    new_env = %{name: nil}

    path = product_environments_path(Endpoint, :create, product.name)

    conn = call(Router, :post, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 400

    assert num_environments == length(Repo.all(ProductEnvironment))
  end

  test "update action -- success", context do
    product = context[:product]
    env = context[:pe1]

    new_env = %{name: "updated environment name"}

    path = product_environments_path(Endpoint, :update, product.name, env.name)

    conn = call(Router, :put, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 204

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/products/#{product.name}/environments/#{new_env.name}" == location

    env = Repo.get(ProductEnvironment, env.id)

    assert env.name == new_env.name
  end

  test "update action -- fails on conflicting name", context do
    product = context[:product]
    env1 = context[:pe1]
    env2 = context[:pe2]

    new_env = %{name: env2.name}

    path = product_environments_path(Endpoint, :update, product.name, env1.name)

    conn = call(Router, :put, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 409
  end

  test "update action -- product not found", context do
    env = context[:pe1]

    new_env = %{name: "updated environment name"}

    path = product_environments_path(Endpoint, :update, "not a real product name", env.name)

    conn = call(Router, :put, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 404
  end

  test "update action -- environment not found", context do
    product = context[:product]

    new_env = %{name: "updated name"}

    path = product_environments_path(Endpoint, :update, product.name, "not a real environment name")

    conn = call(Router, :put, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 404
  end

  test "update action -- fails on bad environment name", context do
    product = context[:product]
    env = context[:pe1]

    new_env = %{name: ""}

    path = product_environments_path(Endpoint, :update, product.name, env.name)

    conn = call(Router, :put, path, Poison.encode!(new_env), [{"content-type", "application/json"}])

    assert conn.status == 400
  end

  test "destroy action -- success for environment with associated variables", context do
    product = context[:product]
    env = context[:pe1]

    num_environments = length(Repo.all(ProductEnvironment))
    num_variables = length(Repo.all(ProductEnvironmentalVariable))

    path = product_environments_path(Endpoint, :destroy, product.name, env.name)

    conn = call(Router, :delete, path)

    assert conn.status == 204

    assert num_environments - 1 == length(Repo.all(ProductEnvironment))
    assert num_variables - 2 == length(Repo.all(ProductEnvironmentalVariable))
  end

  test "destroy action -- success for environment with no associated variable", context do
    product = context[:product]
    new_env = ProductEnvironment.new(%{name: "another_test_env", product_id: product.id})
              |> Repo.insert

    num_environments = length(Repo.all(ProductEnvironment))
    num_variables = length(Repo.all(ProductEnvironmentalVariable))

    path = product_environments_path(Endpoint, :destroy, product.name, new_env.name)

    conn = call(Router, :delete, path)

    assert conn.status == 204

    assert num_environments - 1 == length(Repo.all(ProductEnvironment))
    assert num_variables == length(Repo.all(ProductEnvironmentalVariable))
  end

  test "destroy action -- environment not found", context do
    product = context[:product]

    num_environments = length(Repo.all(ProductEnvironment))
    num_variables = length(Repo.all(ProductEnvironmentalVariable))

    path = product_environments_path(Endpoint, :destroy, product.name, "not a real environment name")

    conn = call(Router, :delete, path)

    assert conn.status == 404

    assert num_environments == length(Repo.all(ProductEnvironment))
    assert num_variables == length(Repo.all(ProductEnvironmentalVariable))
  end

  test "destroy action -- product not found", context do
    env = context[:pe1]

    num_environments = length(Repo.all(ProductEnvironment))
    num_variables = length(Repo.all(ProductEnvironmentalVariable))

    path = product_environments_path(Endpoint, :destroy, "not a real product name", env.name)

    conn = call(Router, :delete, path)

    assert conn.status == 404

    assert num_environments == length(Repo.all(ProductEnvironment))
    assert num_variables == length(Repo.all(ProductEnvironmentalVariable))
  end
end