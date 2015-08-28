defmodule OpenAperture.Manager.Controllers.ProductDeploymentStepsTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  import OpenAperture.Manager.Router.Helpers
  import Ecto.Query

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductEnvironment
  alias OpenAperture.Manager.DB.Models.ProductDeployment
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Models.ProductDeploymentStep
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep

  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn -> :meck.unload end
  end

  setup do
    Repo.delete_all(ProductDeploymentStep)
    Repo.delete_all(ProductDeployment)
    Repo.delete_all(ProductDeploymentPlanStep)
    Repo.delete_all(ProductDeploymentPlan)
    Repo.delete_all(ProductEnvironment)
    Repo.delete_all(Product)
          
    product = Product.new(%{name: "test_pds_product"})
              |> Repo.insert!

    pdp1 = ProductDeploymentPlan.new(%{name: "test_pdp1", product_id: product.id})
           |> Repo.insert!

    pe1 = ProductEnvironment.new(%{name: "test_environment_1", product_id: product.id})
          |> Repo.insert!

    pd1 = ProductDeployment.new(%{product_id: product.id, product_environment_id: pe1.id, product_deployment_plan_id: pdp1.id})
           |> Repo.insert!
    pd2 = ProductDeployment.new(%{product_id: product.id, product_environment_id: pe1.id, product_deployment_plan_id: pdp1.id})
           |> Repo.insert!

    pdps1 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_component"})
            |> Repo.insert!

    pds1 = ProductDeploymentStep.new(%{product_deployment_id: pd1.id})
            |> Repo.insert!
    pds2 = ProductDeploymentStep.new(%{product_deployment_id: pd1.id})
            |> Repo.insert!
    pds6 = ProductDeploymentStep.new(%{product_deployment_id: pd1.id})
            |> Repo.insert!
    pds3 = ProductDeploymentStep.new(%{product_deployment_id: pd1.id})
            |> Repo.insert!
    pds4 = ProductDeploymentStep.new(%{product_deployment_id: pd1.id})
            |> Repo.insert!
    pds5 = ProductDeploymentStep.new(%{product_deployment_id: pd1.id})
            |> Repo.insert!

    on_exit fn ->
      Repo.delete_all(ProductDeploymentStep)
      Repo.delete_all(ProductDeployment)
      Repo.delete_all(ProductDeploymentPlanStep)
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(ProductEnvironment)
      Repo.delete_all(Product)
    end

    {:ok, product: product, pd1: pd1, pd2: pd2, pdps1: pdps1, pds1: pds1, pds2: pds2, pds3: pds3, pds4: pds4, pds5: pds5}
  end

  @endpoint OpenAperture.Manager.Endpoint

  test "index action -- success", context do
    product = context[:product]
    deployment = context[:pd1]

    path = product_deployment_steps_path(Endpoint, :index, product.name, deployment.id)

    conn = get conn(), path

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 6
  end

  test "index action -- no steps for deployment or deployment not found", context do
    product = context[:product]

    path = product_deployment_steps_path(Endpoint, :index,-1, -1)

    conn = get conn(), path

    assert conn.status == 200
    assert conn.resp_body |> Poison.decode! |> length == 0
  end

  test "create action -- success", context do
    product = context[:product]
    step = context[:pdps1]
    deployment = context[:pd1]

    path = product_deployment_steps_path(Endpoint, :create, product.name, deployment.id)

    conn = post conn(), path, %{product_deployment_plan_step_id: step.id, completed: false, output: "[]"}

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location != nil
  end

  test "create action -- failure, deployment invalid", context do
    product = context[:product]
    step = context[:pdps1]

    path = product_deployment_steps_path(Endpoint, :create, product.name, -1)

    conn = post conn(), path, %{product_deployment_plan_step_id: step.id, completed: false, output: "[]"}

    assert conn.status == 404
  end

  test "create action -- failure, invalid changeset", context do
    product = context[:product]
    deployment = context[:pd1]

    path = product_deployment_steps_path(Endpoint, :create, product.name, deployment.id)

    conn = post conn(), path, %{product_deployment_plan_step_id: "asdf", completed: false, output: "[]"}

    assert conn.status == 400
  end

  test "show action -- success", context do
    product = context[:product]
    step = context[:pds1]
    deployment = context[:pd1]

    path = product_deployment_steps_path(Endpoint, :show, product.name, deployment.id, step.id)

    conn = get conn(), path

    assert conn.status == 200

    body = conn.resp_body |> Poison.decode!

    assert body["id"] == step.id
  end

  test "show action -- failure, not found", context do
    product = context[:product]
    deployment = context[:pd1]

    path = product_deployment_steps_path(Endpoint, :show, product.name, deployment.id, -1)

    conn = get conn(), path

    assert conn.status == 404
  end

  test "update action -- success", context do 
    product = context[:product]
    deployment = context[:pd1]
    step = context[:pds1]

    path = product_deployment_steps_path(Endpoint, :update, product.name, deployment.id, step.id)

    conn = put conn(), path, %{successful: true}

    assert conn.status == 204

    assert Repo.get(ProductDeploymentStep, step.id).successful == true
  end

  test "update action -- failure, deployment/deployment_step not found", context do 
    product = context[:product]
    deployment = context[:pd1]
    step = context[:pds1]

    path = product_deployment_steps_path(Endpoint, :update, product.name, -1, -1)

    conn = put conn(), path, %{successful: true}

    assert conn.status == 404
  end

  test "update action -- failure, invalid changeset", context do 
    product = context[:product]
    deployment = context[:pd1]
    step = context[:pds1]

    path = product_deployment_steps_path(Endpoint, :update, product.name, deployment.id, step.id)

    conn = put conn(), path, %{product_deployment_id: "asdf"}

    assert conn.status == 400
  end

  test "delete action -- success", context do
    product = context[:product]
    deployment = context[:pd1]
    step = context[:pds1]

    path = product_deployment_steps_path(Endpoint, :destroy, product.name, deployment.id, step.id)

    conn = delete conn(), path

    assert conn.status == 204

    assert nil = Repo.get(ProductDeploymentStep, step.id)
  end

  test "delete action -- failure, step/deployment not found", context do
    product = context[:product]

    path = product_deployment_steps_path(Endpoint, :destroy, product.name, -1, -1)

    conn = delete conn(), path

    assert conn.status == 404
  end
end