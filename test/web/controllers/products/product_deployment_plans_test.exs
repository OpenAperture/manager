defmodule OpenAperture.Manager.Controllers.ProductDeploymentPlansTest do
  use ExUnit.Case, async: false
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Router

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStepOption
  
  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit fn -> :meck.unload end
  end

  @endpoint OpenAperture.Manager.Endpoint

  setup do
    product = Product.new(%{name: "test_pdp_product"})
              |> Repo.insert

    pdp1 = ProductDeploymentPlan.new(%{name: "test_pdp1", product_id: product.id})
           |> Repo.insert
    pdp2 = ProductDeploymentPlan.new(%{name: "test_pdp2", product_id: product.id})
           |> Repo.insert
    pdp3 = ProductDeploymentPlan.new(%{name: "test_pdp3", product_id: product.id})
           |> Repo.insert

    step1 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_component"})
            |> Repo.insert

    option1 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step1.id, name: "test_option"})
              |> Repo.insert

    on_exit fn ->
      Repo.delete_all(ProductDeploymentPlanStepOption)
      Repo.delete_all(ProductDeploymentPlanStep)
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    {:ok, product: product, pdp1: pdp1, pdp2: pdp2, pdp3: pdp3, step1: step1, option1: option1}
  end

  test "index action -- success", context do
    product = context[:product]

    path = product_deployment_plans_path(Endpoint, :index, product.name)

    conn = get conn(), path

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 3
  end

  test "index action -- product exists, no associated deployment plans" do
    product = Product.new(%{name: "product_with_no_deployment_plans"})
              |> Repo.insert

    path = product_deployment_plans_path(Endpoint, :index, product.name)

    conn = get conn(), path

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index action -- product doesn't exist" do
    path = product_deployment_plans_path(Endpoint, :index, "not a real product name")

    conn = get conn(), path

    assert conn.status == 404
  end

  test "show action -- success", context do
    product = context[:product]
    plan = context[:pdp1]

    path = product_deployment_plans_path(Endpoint, :show, product.name, plan.name)

    conn = get conn(), path

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["name"] == plan.name
  end

  test "show action -- success with URI-encoded plan name", context do
    product = context[:product]

    name = "Test Plan & with ^ we#ird char@cters"
    ProductDeploymentPlan.new(%{name: name, product_id: product.id})
    |> Repo.insert

    name_encoded = URI.encode(name, &URI.char_unreserved?/1)
    path = product_deployment_plans_path(Endpoint, :show, product.name, name_encoded)

    conn = get conn(), path

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["name"] == name
  end

  test "show action -- product not found", context do
    plan = context[:pdp1]
    path = product_deployment_plans_path(Endpoint, :show, "not a real product name", plan.name)

    conn = get conn(), path

    assert conn.status == 404
  end

  test "show action -- deployment plan not found", context do
    product = context[:product]
    path = product_deployment_plans_path(Endpoint, :show, product.name, "not a real deployment plan name")

    conn = get conn(), path

    assert conn.status == 404
  end

  test "create action -- success", context do
    product = context[:product]
    path = product_deployment_plans_path(Endpoint, :create, product.name)

    new_plan = %{name: "test_plan"}

    conn = post conn(), path, new_plan

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/products/#{product.name}/deployment_plans/#{new_plan.name}" == location
  end

  test "create action -- similarly-named plan already exists", context do
    product = context[:product]
    plan = context[:pdp1]
    path = product_deployment_plans_path(Endpoint, :create, product.name)

    new_plan = %{name: plan.name}

    conn = call(Router, :post, path, Poison.encode!(new_plan), [{"content-type", "application/json"}])

    assert conn.status == 409
  end

  test "create action -- product doesn't exist" do
    path = product_deployment_plans_path(Endpoint, :create, "not a real product name")

    new_plan = %{name: "test_plan"}

    conn = post conn(), path, new_plan

    assert conn.status == 404
  end

  test "create action -- invalid plan", context do
    product = context[:product]
    path = product_deployment_plans_path(Endpoint, :create, product.name)

    new_plan = %{}

    conn = post conn(), path, new_plan

    assert conn.status == 400
  end

  test "update action -- success", context do
    product = Map.from_struct(context[:product])
    plan = Map.from_struct(context[:pdp1])

    path = product_deployment_plans_path(Endpoint, :update, product.name, plan.name)

    updated_plan = %{plan | name: "some_new_name"}
    conn = put conn(), path, updated_plan

    assert conn.status == 204

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/products/#{product.name}/deployment_plans/#{updated_plan.name}" == location

    retrieved = Repo.get(ProductDeploymentPlan, plan.id)
    assert retrieved.id == plan.id
    assert retrieved.name == updated_plan.name
  end

  test "update action -- success and deletes existing plan if conflicting name", context do
    # Update plan2 with plan1's name, which should delete plan1 (and it's
    # associated step and option).
    product = Map.from_struct(context[:product])
    plan1 = Map.from_struct(context[:pdp1])
    plan2 = Map.from_struct(context[:pdp2])
    step = Map.from_struct(context[:step1])
    option = Map.from_struct(context[:option1])

    path = product_deployment_plans_path(Endpoint, :update, product.name, plan2.name)

    updated_plan = %{plan2 | name: plan1.name}
    conn = put conn(), path, updated_plan

    assert conn.status == 204

    assert nil == Repo.get(ProductDeploymentPlan, plan1.id)
    assert nil == Repo.get(ProductDeploymentPlanStep, step.id)
    assert nil == Repo.get(ProductDeploymentPlanStepOption, option.id)
  end

  test "update action -- plan not found", context do
    product = context[:product]

    path = product_deployment_plans_path(Endpoint, :update, product.name, "not a real plan name")

    updated_plan = %{name: "some name"}
    conn =  put conn(), path, updated_plan

    assert conn.status == 404
  end

  test "update action -- product not found", context do
    plan = Map.from_struct(context[:pdp1])

    path = product_deployment_plans_path(Endpoint, :update, "not a real product name", plan.name)

    updated_plan = %{plan| name: "some name"}
    conn =  put conn(), path, updated_plan

    assert conn.status == 404
  end

  test "destroy_all_plans action -- success", context do
    product = context[:product]
    plan1 = context[:pdp1]
    plan2 = context[:pdp2]
    plan3 = context[:pdp3]

    path = product_deployment_plans_path(Endpoint, :destroy_all_plans, product.name)

    conn =  delete conn(), path

    assert conn.status == 204

    assert nil = Repo.get(ProductDeploymentPlan, plan1.id)
    assert nil = Repo.get(ProductDeploymentPlan, plan2.id)
    assert nil = Repo.get(ProductDeploymentPlan, plan3.id)
  end

  test "destroy_all_plans action -- success, deletes associated plan steps and step options", context do
    product = context[:product]
    plan1 = context[:pdp1]
    step = context[:step1]
    option = context[:option1]

    path = product_deployment_plans_path(Endpoint, :destroy_all_plans, product.name)

    conn = delete conn(), path

    assert conn.status == 204

    assert nil = Repo.get(ProductDeploymentPlan, plan1.id)
    assert nil = Repo.get(ProductDeploymentPlanStep, step.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option.id)
  end

  test "destroy_all_plans -- product not found" do
    path = product_deployment_plans_path(Endpoint, :destroy_all_plans, "not a real product name")

    conn = delete conn(), path

    assert conn.status == 404
  end

  test "destroy_plan -- success", context do
    product = context[:product]
    plan2 = context[:pdp2]

    path = product_deployment_plans_path(Endpoint, :destroy_plan, product.name, plan2.name)

    conn = delete conn(), path

    assert conn.status == 204

    assert nil == Repo.get(ProductDeploymentPlan, plan2.id)
  end

  test "destroy_plan -- success, deletes associated deployment plan steps and options", context do
    product = context[:product]
    plan1 = context[:pdp1]
    step = context[:step1]
    option = context[:option1]

    path = product_deployment_plans_path(Endpoint, :destroy_plan, product.name, plan1.name)

    conn = delete conn(), path

    assert conn.status == 204

    assert nil = Repo.get(ProductDeploymentPlan, plan1.id)
    assert nil = Repo.get(ProductDeploymentPlanStep, step.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option.id)
  end

  test "destroy_plan -- plan not found", context do
    product = context[:product]

    path = product_deployment_plans_path(Endpoint, :destroy_plan, product.name, "not a real plan name")

    conn = delete conn(), path

    assert conn.status == 404
  end

  test "destroy_plan -- product not found", context do
    plan = context[:pdp1]

    path = product_deployment_plans_path(Endpoint, :destroy_plan, "not a real product name", plan.name)

    conn = delete conn(), path

    assert conn.status == 404
  end
end