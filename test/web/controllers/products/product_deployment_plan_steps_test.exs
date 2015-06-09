defmodule OpenAperture.Manager.Controllers.ProductDeploymentPlanStepsTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStepOption

  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit fn -> :meck.unload end
  end

  setup do
    product = Product.new(%{name: "test_pdps_product"})
              |> Repo.insert

    pdp1 = ProductDeploymentPlan.new(%{name: "test_pdps_pdp1", product_id: product.id})
           |> Repo.insert
    pdp2 = ProductDeploymentPlan.new(%{name: "test_pdps_pdp2", product_id: product.id})
           |> Repo.insert

    pdps1 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_component"})
            |> Repo.insert
    pdps2 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "deploy_component"})
            |> Repo.insert
    pdps3 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_deploy_component", on_success_step_id: pdps1.id, on_failure_step_id: pdps2.id})
            |> Repo.insert
    pdps4 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_deploy_component", on_success_step_id: pdps1.id, on_failure_step_id: pdps2.id})
            |> Repo.insert


    pdpso1 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: pdps4.id, name: "test_option1"})
             |> Repo.insert
    pdpso2 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: pdps4.id, name: "test_option2", value: "TWO"})
             |> Repo.insert
    pdpso3 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: pdps4.id, name: "test_option3", value: "three"})
             |> Repo.insert

    on_exit fn ->
      Repo.delete_all(ProductDeploymentPlanStepOption)
      Repo.delete_all(ProductDeploymentPlanStep)
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    {:ok, product: product, pdp1: pdp1, pdp2: pdp2, pdps1: pdps1, pdps2: pdps2, pdps3: pdps3, pdps4: pdps4, pdpso1: pdpso1, pdpso2: pdpso2, pdpso3: pdpso3}
  end

  @endpoint OpenAperture.Manager.Endpoint

  test "index action -- success", context do
    product = context[:product]
    plan = context[:pdp1]

    path = product_deployment_plan_steps_path(Endpoint, :index, product.name, plan.name)

    conn = get conn(), path

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["type"] == "build_deploy_component"

    assert length(body["options"]) == 3
  end

  test "index action -- plan with no steps -- success", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :index, product.name, plan.name)

    conn = get conn(), path

    assert conn.status == 204

    assert conn.resp_body == ""
  end

  test "index action -- product not found", context do
    plan = context[:pdp1]

    path = product_deployment_plan_steps_path(Endpoint, :index, "not a real product name", plan.name)

    conn = get conn(), path

    assert conn.status == 404
  end

  test "index action -- plan not found", context do
    product = context[:product]

    path = product_deployment_plan_steps_path(Endpoint, :index, product.name, "not a real deployment plan name")

    conn = get conn(), path

    assert conn.status == 404
  end

  test "create action -- success, nested steps", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))

    step1_deploy = %{type: "deploy_component", product_deployment_plan_id: plan.id}
    step1_error = %{type: "execute_plan", product_deployment_plan_id: plan.id}
    step1_build = %{type: "build_component", product_deployment_plan_id: plan.id, on_success_step: step1_deploy, on_failure_step: step1_error}

    conn = post conn(), path, step1_build

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == path

    assert step_count + 3 == length(Repo.all(ProductDeploymentPlanStep))
  end

  test "create action -- success, single step", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))

    step1_deploy = %{type: "deploy_component", product_deployment_plan_id: plan.id}

    conn = post conn(), path, step1_deploy

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == path

    assert step_count + 1 == length(Repo.all(ProductDeploymentPlanStep))
  end

  test "create action -- success, nested steps, with options", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))
    option_count = length(Repo.all(ProductDeploymentPlanStepOption))

    step1_option1 = %{name: "test_option1", value: "one"}
    step1_option2 = %{name: "test_option2", value: "two"}
    step2_option1 = %{name: "test_option3", value: "three"}
    step3_option1 = %{name: "test_option4", value: "four"}

    step1_deploy = %{type: "deploy_component", product_deployment_plan_id: plan.id, options: [step1_option1, step1_option2]}
    step1_error = %{type: "execute_plan", product_deployment_plan_id: plan.id, options: [step2_option1]}
    step1_build = %{type: "build_component", product_deployment_plan_id: plan.id, on_success_step: step1_deploy, on_failure_step: step1_error, options: [step3_option1]}

    conn = post conn(), path, step1_build

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == path

    assert step_count + 3 == length(Repo.all(ProductDeploymentPlanStep))
    assert option_count + 4 == length(Repo.all(ProductDeploymentPlanStepOption))
  end

  test "create action -- success, single step, with options", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))
    option_count = length(Repo.all(ProductDeploymentPlanStepOption))

    step1_option1 = %{name: "test_option1", value: "one"}
    step1_option2 = %{name: "test_option2", value: "two"}
    step1_option3 = %{name: "test_option3", value: "three"}

    step1_deploy = %{type: "deploy_component", product_deployment_plan_id: plan.id, options: [step1_option1, step1_option2, step1_option3]}

    conn = post conn(), path, step1_deploy

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == path

    assert step_count + 1 == length(Repo.all(ProductDeploymentPlanStep))
    assert option_count + 3 == length(Repo.all(ProductDeploymentPlanStepOption))
  end

  test "create action -- invalid nested step", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))

    step1_deploy = %{type: "NOT A REAL STEP TYPE", product_deployment_plan_id: plan.id}
    step1_error = %{type: "execute_plan", product_deployment_plan_id: plan.id}
    step1_build = %{type: "build_component", product_deployment_plan_id: plan.id, on_success_step: step1_deploy, on_failure_step: step1_error}

    conn = post conn(), path, step1_build

    assert conn.status == 400
    assert step_count == length(Repo.all(ProductDeploymentPlanStep))
  end

  test "create action -- invalid root step", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))

    step1_deploy = %{type: "deploy_component", product_deployment_plan_id: plan.id}
    step1_error = %{type: "execute_plan", product_deployment_plan_id: plan.id}
    step1_build = %{type: "NOT A REAL STEP TYPE", product_deployment_plan_id: plan.id, on_success_step: step1_deploy, on_failure_step: step1_error}

    conn = post conn(), path, step1_build

    assert conn.status == 400
    assert step_count == length(Repo.all(ProductDeploymentPlanStep))
  end

  test "create action -- invalid single step", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))

    step1_deploy = %{type: "NOT A VALID STEP TYPE", product_deployment_plan_id: plan.id}

    conn = post conn(), path, step1_deploy

    assert conn.status == 400
    assert step_count == length(Repo.all(ProductDeploymentPlanStep))
  end

  test "create action -- nested steps with invalid option", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))
    option_count = length(Repo.all(ProductDeploymentPlanStepOption))

    step1_option1 = %{value: "one"}
    step1_option2 = %{name: "test_option2", value: "two"}
    step2_option1 = %{name: "test_option3", value: "three"}
    step3_option1 = %{name: "test_option4", value: "four"}

    step1_deploy = %{type: "deploy_component", product_deployment_plan_id: plan.id, options: [step1_option1, step1_option2]}
    step1_error = %{type: "execute_plan", product_deployment_plan_id: plan.id, options: [step2_option1]}
    step1_build = %{type: "build_component", product_deployment_plan_id: plan.id, on_success_step: step1_deploy, on_failure_step: step1_error, options: [step3_option1]}

    conn = post conn(), path, step1_build

    assert conn.status == 400
    assert step_count == length(Repo.all(ProductDeploymentPlanStep))
    assert option_count == length(Repo.all(ProductDeploymentPlanStepOption))
  end

  test "create action -- single step with invalid option", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))
    option_count = length(Repo.all(ProductDeploymentPlanStepOption))

    step1_option1 = %{value: "one"}
    step1_option2 = %{name: "test_option2", value: "two"}
    step1_option3 = %{name: "test_option3", value: "three"}

    step1_deploy = %{type: "deploy_component", product_deployment_plan_id: plan.id, options: [step1_option1, step1_option2, step1_option3]}

    conn = post conn(), path, step1_deploy

    assert conn.status == 400
    assert step_count == length(Repo.all(ProductDeploymentPlanStep))
    assert option_count == length(Repo.all(ProductDeploymentPlanStepOption))
  end

  test "delete action -- success", context do
    product = context[:product]
    plan = context[:pdp1]

    path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name)

    conn = delete conn(), path

    assert conn.status == 204

    step1 = context[:pdps1]
    step2 = context[:pdps2]
    step3 = context[:pdps3]
    option1 = context[:pdpso1]
    option2 = context[:pdpso2]
    option3 = context[:pdpso3]

    assert nil = Repo.get(ProductDeploymentPlanStep, step1.id)
    assert nil = Repo.get(ProductDeploymentPlanStep, step2.id)
    assert nil = Repo.get(ProductDeploymentPlanStep, step3.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option1.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option2.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option3.id)
  end

  test "delete action -- success for plan with no associated steps", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name)

    conn = delete conn(), path

    assert conn.status == 204

    step1 = context[:pdps1]

    # Verify the delete didn't affect steps associatied with a different plan
    assert Repo.get(ProductDeploymentPlanStep, step1.id) != nil
  end

  test "delete action -- product not found", context do
    plan = context[:pdp2]
    path = product_deployment_plan_steps_path(Endpoint, :destroy, "not a real product name", plan.name)

    conn = delete conn(), path

    assert conn.status == 404
  end

  test "delete action -- plan not found", context do
    product = context[:product]
    path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, "not a real plan name")

    conn = delete conn(), path

    assert conn.status == 404
  end
end