defmodule OpenAperture.Manager.Controllers.ProductDeploymentPlanStepsTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  import OpenAperture.Manager.Router.Helpers
  import Ecto.Query

  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStep
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlanStepOption

  setup_all do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)

    on_exit fn -> :meck.unload end
  end

  setup do
    product = Product.new(%{name: "test_pdps_product"})
              |> Repo.insert!

    pdp1 = ProductDeploymentPlan.new(%{name: "test_pdps_pdp1", product_id: product.id})
           |> Repo.insert!
    pdp2 = ProductDeploymentPlan.new(%{name: "test_pdps_pdp2", product_id: product.id})
           |> Repo.insert!

    pdps1 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_component"})
            |> Repo.insert!
    pdps2 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "deploy_component"})
            |> Repo.insert!
    pdps6 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "deploy_component"})
            |> Repo.insert!
    pdps3 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_deploy_component", on_success_step_id: pdps1.id, on_failure_step_id: pdps2.id})
            |> Repo.insert!
    pdps4 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_deploy_component", on_success_step_id: pdps6.id})
            |> Repo.insert!
    pdps5 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: pdp1.id, type: "build_deploy_component", on_success_step_id: pdps3.id, on_failure_step_id: pdps4.id})
            |> Repo.insert!


    pdpso1 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: pdps5.id, name: "test_option1"})
             |> Repo.insert!
    pdpso2 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: pdps5.id, name: "test_option2", value: "TWO"})
             |> Repo.insert!
    pdpso3 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: pdps5.id, name: "test_option3", value: "three"})
             |> Repo.insert!
    pdpso5 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: pdps1.id, name: "test_option5", value: "cinco"})
             |> Repo.insert!

    on_exit fn ->
      Repo.delete_all(ProductDeploymentPlanStepOption)
      Repo.delete_all(ProductDeploymentPlanStep)
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    {:ok, product: product, pdp1: pdp1, pdp2: pdp2, pdps1: pdps1, pdps2: pdps2, pdps3: pdps3, pdps4: pdps4, pdps5: pdps5, pdpso1: pdpso1, pdpso2: pdpso2, pdpso3: pdpso3, pdpso5: pdpso5}
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

  test "create action -- success, single step as child", context do
    product = context[:product]
    plan = context[:pdp1]
    step1 = context[:pdps1]

    path = product_deployment_plan_steps_path(Endpoint, :create, product.name, plan.name)

    step_count = length(Repo.all(ProductDeploymentPlanStep))

    step1_deploy = %{type: "deploy_component", product_deployment_plan_id: plan.id, parent_step_id: step1.id, step_case: "success"}

    conn = post conn(), path, step1_deploy

    assert conn.status == 201



    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert location == path

    assert step_count + 1 == length(Repo.all(ProductDeploymentPlanStep))
    assert nil != Repo.get(ProductDeploymentPlanStep, step1.id).on_success_step_id
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

  test "update action -- success, destroys all options", context do 
    product = context[:product]
    plan = context[:pdp1]
    step5 = context[:pdps5]
    option1 = context[:pdpso1]
    option2 = context[:pdpso2]
    option3 = context[:pdpso3]

   # path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name, step1.id)
    path = "/products/#{product.name}/deployment_plans/#{plan.name}/steps/#{step5.id}"

    conn = put conn(), path, %{type: "deploy_component"}

    assert conn.status == 204

    assert "deploy_component" = Repo.get(ProductDeploymentPlanStep, step5.id).type
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option1.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option2.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option3.id)
  end
  test "update action -- success, destroys options and remakes them", context do 
    product = context[:product]
    plan = context[:pdp1]
    step5 = context[:pdps5]
    option1 = context[:pdpso1]
    option2 = context[:pdpso2]
    option3 = context[:pdpso3]

   # path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name, step1.id)
    path = "/products/#{product.name}/deployment_plans/#{plan.name}/steps/#{step5.id}"

    conn = put conn(), path, %{type: "deploy_component", options: [Map.from_struct(option1), Map.from_struct(option2), Map.from_struct(option3)]}

    assert conn.status == 204

    assert "deploy_component" = Repo.get(ProductDeploymentPlanStep, step5.id).type
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option1.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option2.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option3.id)

    options = Repo.all(  
      from pdpso in ProductDeploymentPlanStepOption,
      where: pdpso.product_deployment_plan_step_id == ^step5.id,
      select: pdpso
    )
    assert 3 = length(options)
  end

  test "update action -- step not found", context do 
    product = context[:product]
    plan = context[:pdp1]
    step1 = context[:pdps1]

   # path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name, step1.id)
    path = "/products/#{product.name}/deployment_plans/#{plan.name}/steps/-1"

    conn = put conn(), path, %{type: "deploy_component"}

    assert conn.status == 404

    assert "build_component" = Repo.get(ProductDeploymentPlanStep, step1.id).type
  end

  test "update action -- invalid change", context do
    product = context[:product]
    plan = context[:pdp1]
    step1 = context[:pdps1]

   # path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name, step1.id)
    path = "/products/#{product.name}/deployment_plans/#{plan.name}/steps/#{step1.id}"

    conn = put conn(), path, %{type: "not a valid type"}

    assert conn.status == 400

    assert "build_component" = Repo.get(ProductDeploymentPlanStep, step1.id).type
  end

  test "delete action, all steps for plan -- success", context do
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

  test "delete action, all steps for plan -- success for plan with no associated steps", context do
    product = context[:product]
    plan = context[:pdp2]

    path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name)

    conn = delete conn(), path

    assert conn.status == 204

    step1 = context[:pdps1]

    # Verify the delete didn't affect steps associatied with a different plan
    assert Repo.get(ProductDeploymentPlanStep, step1.id) != nil
  end

  test "delete action, all steps for plan -- product not found", context do
    plan = context[:pdp2]
    path = product_deployment_plan_steps_path(Endpoint, :destroy, "not a real product name", plan.name)

    conn = delete conn(), path

    assert conn.status == 404
  end

  test "delete action, all steps for plan -- plan not found", context do
    product = context[:product]
    path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, "not a real plan name")

    conn = delete conn(), path

    assert conn.status == 404
  end

  test "delete action, single step, no children, has parent -- success", context do
    product = context[:product]
    plan = context[:pdp1]
    step1 = context[:pdps1]
    step3 = context[:pdps3]

   # path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name, step1.id)
    path = "/products/#{product.name}/deployment_plans/#{plan.name}/steps/#{step1.id}"

    conn = delete conn(), path

    assert conn.status == 204

    assert nil = Repo.get(ProductDeploymentPlanStep, step1.id)
    assert nil = Repo.get(ProductDeploymentPlanStep, step3.id).on_success_step_id
  end

  test "delete action, single step, has children, no parent -- success", context do
    product = context[:product]
    plan = context[:pdp1]
    step3 = context[:pdps3]
    option3 = context[:pdpso3]
    step5 = context[:pdps5]
    option5 = context[:pdpso5]

    #path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name, step5.id)
    path = "/products/#{product.name}/deployment_plans/#{plan.name}/steps/#{step5.id}"

    conn = delete conn(), path

    assert conn.status == 204

    assert nil = Repo.get(ProductDeploymentPlanStep, step3.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option3.id)
    assert nil = Repo.get(ProductDeploymentPlanStep, step5.id)
    assert nil = Repo.get(ProductDeploymentPlanStepOption, option5.id)
  end

  test "delete action, single step, has children, has parent -- success", context do
    product = context[:product]
    plan = context[:pdp1]
    step1 = context[:pdps1]
    step3 = context[:pdps3]
    step5 = context[:pdps5]

    #path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, plan.name, step3.id)
    path = "/products/#{product.name}/deployment_plans/#{plan.name}/steps/#{step3.id}"

    conn = delete conn(), path

    assert conn.status == 204

    assert nil = Repo.get(ProductDeploymentPlanStep, step3.id)
    assert nil = Repo.get(ProductDeploymentPlanStep, step1.id)
    assert nil = Repo.get(ProductDeploymentPlanStep, step5.id).on_success_step_id
  end

  test "delete action, single step -- product not found", context do
    plan = context[:pdp2]
    path = product_deployment_plan_steps_path(Endpoint, :destroy, "not a real product name", plan.name)

    conn = delete conn(), path

    assert conn.status == 404
  end

  test "delete action, single step -- plan not found", context do
    product = context[:product]
    path = product_deployment_plan_steps_path(Endpoint, :destroy, product.name, "not a real plan name")

    conn = delete conn(), path

    assert conn.status == 404
  end
end