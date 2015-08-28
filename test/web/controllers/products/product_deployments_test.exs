defmodule OpenAperture.Manager.Controllers.ProductDeploymentsTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeployment
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Models.ProductDeploymentStep
  alias OpenAperture.Manager.DB.Models.ProductEnvironment

  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn -> :meck.unload end
  end

  setup do
    Repo.delete_all(ProductDeploymentStep)
    Repo.delete_all(ProductDeployment)
    Repo.delete_all(ProductDeploymentPlan)
    Repo.delete_all(ProductEnvironment)
    Repo.delete_all(Product)

    product = Product.new(%{name: "product1"})
      |> Repo.insert!

    pdp1 = ProductDeploymentPlan.new(%{product_id: product.id, name: "plan1"})
      |> Repo.insert!

    pe1 = ProductEnvironment.new(%{product_id: product.id, name: "test_env"})
      |> Repo.insert!

    pd1 = ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: pdp1.id, product_environment_id: pe1.id})
      |> Repo.insert!

    pd2 = ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: pdp1.id, product_environment_id: pe1.id})
      |> Repo.insert!

    _pds1 = ProductDeploymentStep.new(%{product_deployment_id: pd1.id})
      |> Repo.insert!

    _pds2 = ProductDeploymentStep.new(%{product_deployment_id: pd1.id})
      |> Repo.insert!

    on_exit fn ->
      Repo.delete_all(ProductDeploymentStep)
      Repo.delete_all(ProductDeployment)
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(ProductEnvironment)
      Repo.delete_all(Product)
    end

    {:ok, product: product, pdp1: pdp1, pd1: pd1, pd2: pd2, pe1: pe1}
  end

  @endpoint OpenAperture.Manager.Endpoint

  test "index action -- success for single page", context do
    product = context[:product]

    path = product_deployments_path(Endpoint, :index, product.name)

    conn = get conn(), path

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body["deployments"]) == 2
  end


  test "index action -- success for multiple pages", context do
    product = context[:product]
    plan = context[:pdp1]
    environment = context[:pe1]

    #Need at least 21 for 2 pages
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!
    ProductDeployment.new(%{product_id: product.id, product_deployment_plan_id: plan.id, product_environment_id: environment.id}) |> Repo.insert!

    path = product_deployments_path(Endpoint, :index, product.name)

    conn = get conn(), path

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body["deployments"]) == 20
    assert body["total_deployments"] == 21
    assert body["total_pages"] == 2
  end

  test "index action -- product not found" do
    path = product_deployments_path(Endpoint, :index, "notarealproductname")


    conn = get conn(), path
    assert conn.status == 404
  end

  test "show action -- success", context do
    product = context[:product]
    pd = context[:pd1]

    path = product_deployments_path(Endpoint, :show, product.name, pd.id)

    conn = get conn(), path
    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    assert body["id"] == pd.id
    assert body["product_id"] == product.id
  end

  test "show action -- product deployment not found", context do
    product = context[:product]

    path = product_deployments_path(Endpoint, :show, product.name, 123456789)

    conn = get conn(), path
    assert conn.status == 404
  end

  test "show action -- product not found", context do
    pd = context[:pd1]

    path = product_deployments_path(Endpoint, :show, "not a real product name", pd.id)

    conn = get conn(), path
    assert conn.status == 404
  end

  test "create action -- success", context do
    product = context[:product]
    pdp = context[:pdp1]
    environment = context[:pe1]

    num_deployments = length(Repo.all(ProductDeployment))

    path = product_deployments_path(Endpoint, :create, product.name)

    deployment = %{
      plan_name: pdp.name,
      environment_name: environment.name
    }

    conn = post conn(), path, deployment

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert Regex.match?(~r/\/products\/#{product.name}\/deployments\/\d*/, location)

    assert num_deployments + 1 == length(Repo.all(ProductDeployment))
  end

  test "create action -- deployment plan not found", context do
    product = context[:product]
    environment = context[:pe1]
    num_deployments = length(Repo.all(ProductDeployment))
    path = product_deployments_path(Endpoint, :create, product.name)

    deployment = %{
      plan_name: "notarealdeploymentplanname",
      environment_name: environment.name
    }

    conn = post conn(), path, deployment
    assert conn.status == 404

    assert num_deployments == length(Repo.all(ProductDeployment))
  end

  test "create action -- invalid plan name", context do
    product = context[:product]
    num_deployments = length(Repo.all(ProductDeployment))
    path = product_deployments_path(Endpoint, :create, product.name)

    deployment = %{
      plan_name: "",
    }

    conn = post conn(), path, deployment
    assert conn.status == 400

    assert num_deployments == length(Repo.all(ProductDeployment))
  end

  test "create action -- product not found", context do
    pdp = context[:pdp1]
    environment = context[:pe1]
    num_deployments = length(Repo.all(ProductDeployment))
    path = product_deployments_path(Endpoint, :create, "notarealproductname")

    deployment = %{
      plan_name: pdp.name,
      environment_name: environment.name
    }

    asdfasdf = post conn(), path, deployment
    assert asdfasdf.status == 404

    assert num_deployments == length(Repo.all(ProductDeployment))
  end

  test "update action -- success", context do 
    product = context[:product]
    deployment = context[:pd1]
    pdp = context[:pdp1]
    environment = context[:pe1]

    path = product_deployments_path(Endpoint, :update, product.name, deployment.id)

    deployment_params = %{
      completed: true
    }

    conn = put conn(), path, deployment_params

    assert conn.status == 204

    assert Repo.get(ProductDeployment, deployment.id).completed == true
  end

  test "update action -- failure, deployment not found", context do 
    product = context[:product]
    deployment = context[:pd1]
    pdp = context[:pdp1]
    environment = context[:pe1]

    path = product_deployments_path(Endpoint, :update, product.name, -1)

    deployment_params = %{
      completed: true
    }

    conn = put conn(), path, deployment_params

    assert conn.status == 404
  end

  test "update action -- failure, invalid changeset", context do 
    product = context[:product]
    deployment = context[:pd1]
    pdp = context[:pdp1]
    environment = context[:pe1]

    path = product_deployments_path(Endpoint, :update, product.name, deployment.id)

    deployment_params = %{
      completed: 1234
    }

    conn = put conn(), path, deployment_params

    assert conn.status == 400
  end

  test "destroy action -- success", context do
    product = context[:product]
    pd = context[:pd1]
    num_deployments = length(Repo.all(ProductDeployment))
    num_deployment_steps = length(Repo.all(ProductDeploymentStep))

    path = product_deployments_path(Endpoint, :destroy, product.name, pd.id)

    conn = delete conn(), path
    assert conn.status == 204

    assert num_deployments - 1 == length(Repo.all(ProductDeployment))
    assert num_deployment_steps - 2 == length(Repo.all(ProductDeploymentStep))
  end

  test "destroy action -- deployment not found", context do
    product = context[:product]
    num_deployments = length(Repo.all(ProductDeployment))
    num_deployment_steps = length(Repo.all(ProductDeploymentStep))

    path = product_deployments_path(Endpoint, :destroy, product.name, 1234567890)

    conn = delete conn(), path
    assert conn.status == 404

    assert num_deployments == length(Repo.all(ProductDeployment))
    assert num_deployment_steps == length(Repo.all(ProductDeploymentStep))
  end

  test "destroy action -- product not found", context do
    pd = context[:pd1]
    num_deployments = length(Repo.all(ProductDeployment))
    num_deployment_steps = length(Repo.all(ProductDeploymentStep))

    path = product_deployments_path(Endpoint, :destroy, "not a real product name", pd.id)

    conn = delete conn(), path
    assert conn.status == 404

    assert num_deployments == length(Repo.all(ProductDeployment))
    assert num_deployment_steps == length(Repo.all(ProductDeploymentStep))
  end
end