defmodule DB.Models.ProductDeploymentPlanStep.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductComponent
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlan
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlanStep
  alias ProjectOmeletteManager.DB.Queries.ProductDeploymentPlanStep, as: PDPSQuery


  setup _context do
    product = Repo.insert(%Product{name: "test plan"})
    product2 = Repo.insert(%Product{name: "test plan2"})

    plan = Repo.insert(%ProductDeploymentPlan{product_id: product.id, name: "test plan"})

    on_exit _context, fn ->
      Repo.delete_all(ProductDeploymentPlanStep)
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    {:ok, [product: product, product2: product2, plan: plan]}
  end

  test "validate - fail to create plan with missing values", context do
    step   = %ProductDeploymentPlanStep{}
    result = ProductDeploymentPlanStep.validate(step)

    assert map_size(result)
    assert result[:product_deployment_plan_id] != nil
    assert result[:type] != nil
  end

  test "validate - fail to create plan with missing type", context do
    step   = %ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id }
    result = ProductDeploymentPlanStep.validate(step)

    assert map_size(result)
    assert result[:type] != nil
  end

  test "validate - fail to create plan with invalid type", context do
    step = %ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "junk" }

    result = ProductDeploymentPlanStep.validate(step)
    assert map_size(result) != 0
    assert result[:type] != nil
  end

  test "validate - create plan", context do
    step = %ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"}

    result = ProductDeploymentPlanStep.validate(step)
    IO.inspect(result)
    assert is_nil(result)
  end

  test "create plan", context do
    step = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})

    retrieved = Repo.get(ProductDeploymentPlanStep, step.id)
    assert retrieved == step
  end


  #================================
  #to_hierarchy tests

  test "to_hierarchy - invalid input", context do
    assert ProductDeploymentPlanStep.to_hierarchy(nil, true) == nil
  end

  test "to_hierarchy - single node", context do
    root_step = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})

    returned_root_node = ProductDeploymentPlanStep.to_hierarchy([root_step], true)
    assert returned_root_node[:id] == root_step.id
    assert returned_root_node[:on_success_step_id] == nil
    assert returned_root_node[:on_success_step] == nil
    assert returned_root_node[:on_failure_step_id] == nil
    assert returned_root_node[:on_failure_step] == nil
  end

  test "to_hierarchy - one-level multi-node", context do
    success_node = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})
    failure_node = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})

    root_step = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "build_component",
      on_success_step_id: success_node.id,
      on_failure_step_id: failure_node.id
    })

    returned_root_node = ProductDeploymentPlanStep.to_hierarchy(Repo.all(PDPSQuery.get_steps_for_plan(context[:plan].id)), true)
    assert returned_root_node[:id] == root_step.id

    assert returned_root_node[:on_success_step_id] == success_node.id
    assert returned_root_node[:on_success_step] != nil
    assert returned_root_node[:on_success_step][:id] == success_node.id

    assert returned_root_node[:on_failure_step_id] == failure_node.id
    assert returned_root_node[:on_failure_step] != nil
    assert returned_root_node[:on_failure_step][:id] == failure_node.id
  end

  test "to_hierarchy - multi-node", context do
    lvl3 = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "deploy_component"
    })

    lvl2_fail_2 = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "component_script"})
    lvl2_fail = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "deploy_component",
      on_failure_step_id: lvl2_fail_2.id
    })

    lvl2 = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "build_deploy_component",
      on_success_step_id: lvl3.id,
      on_failure_step_id: lvl2_fail.id
    })

    lvl1 = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "build_deploy_component",
      on_success_step_id: lvl2.id
    })

    root_fail = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})
    root_step = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "build_component",
      on_success_step_id: lvl1.id,
      on_failure_step_id: root_fail.id
    })

    child_node = ProductDeploymentPlanStep.to_hierarchy(Repo.all(PDPSQuery.get_steps_for_plan(context[:plan].id)), true)

    #root node
    assert child_node != nil
    assert child_node[:id] == root_step.id
    assert child_node[:on_failure_step_id] == root_fail.id
    assert child_node[:on_failure_step] != nil
    assert child_node[:on_failure_step][:id] == root_fail.id
    assert child_node[:on_success_step_id] == lvl1.id
    child_node = child_node[:on_success_step]

    #lvl1
    assert child_node != nil
    assert child_node[:id] == lvl1.id
    assert child_node[:on_failure_step_id] == nil
    assert child_node[:on_failure_step] == nil
    assert child_node[:on_success_step_id] == lvl2.id
    child_node = child_node[:on_success_step]

    #lvl2
    assert child_node != nil
    assert child_node[:id] == lvl2.id
    assert child_node[:on_failure_step_id] == lvl2_fail.id
    assert child_node[:on_failure_step] != nil
    assert child_node[:on_failure_step][:id] == lvl2_fail.id
    assert child_node[:on_failure_step][:on_failure_step][:id] == lvl2_fail_2.id
    assert child_node[:on_success_step_id] == lvl3.id
    child_node = child_node[:on_success_step]

    #lvl3
    assert child_node != nil
    assert child_node[:id] == lvl3.id
    assert child_node[:on_failure_step_id] == nil
    assert child_node[:on_failure_step] == nil
    assert child_node[:on_success_step_id] == nil
  end


  #================================
  #flatten_hierarchy tests

  test "flatten_hierarchy - invalid input", context do
    assert ProductDeploymentPlanStep.flatten_hierarchy(nil) == nil
  end

  test "flatten_hierarchy - single node", context do
    root_step = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})

    returned_root_node = ProductDeploymentPlanStep.to_hierarchy([root_step], true)
    returned_steps = ProductDeploymentPlanStep.flatten_hierarchy(returned_root_node)
    assert returned_steps != nil
    assert length(returned_steps) == 1
    assert List.first(returned_steps)[:id] == returned_root_node[:id]
  end

  test "flatten_hierarchy - one-level multi-node", context do
    success_node = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})
    failure_node = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})

    root_step = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "build_component",
      on_success_step_id: success_node.id,
      on_failure_step_id: failure_node.id
    })

    returned_root_node = ProductDeploymentPlanStep.to_hierarchy(Repo.all(PDPSQuery.get_steps_for_plan(context[:plan].id)), true)
    returned_steps = ProductDeploymentPlanStep.flatten_hierarchy(returned_root_node)
    assert returned_steps != nil

    expected_step_ids = [success_node.id, failure_node.id, root_step.id]
    assert length(returned_steps) == length(expected_step_ids)

    remaining_ids = Enum.reduce returned_steps, expected_step_ids, fn(returned_step, remaining_ids) ->
      assert returned_step != nil
      List.delete(remaining_ids, returned_step[:id])
    end
    assert length(remaining_ids) == 0
  end

  test "flatten_hierarchy - multi-node", context do
    lvl3 = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "deploy_component"
    })

    lvl2_fail_2 = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "component_script"})
    lvl2_fail = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "deploy_component",
      on_failure_step_id: lvl2_fail_2.id
    })

    lvl2 = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "build_deploy_component",
      on_success_step_id: lvl3.id,
      on_failure_step_id: lvl2_fail.id
    })

    lvl1 = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "build_deploy_component",
      on_success_step_id: lvl2.id
    })

    root_fail = Repo.insert(%ProductDeploymentPlanStep{product_deployment_plan_id: context[:plan].id, type: "build_component"})
    root_step = Repo.insert(%ProductDeploymentPlanStep{
      product_deployment_plan_id: context[:plan].id,
      type: "build_component",
      on_success_step_id: lvl1.id,
      on_failure_step_id: root_fail.id
    })

    returned_root_node = ProductDeploymentPlanStep.to_hierarchy(Repo.all(PDPSQuery.get_steps_for_plan(context[:plan].id)), true)
    returned_steps = ProductDeploymentPlanStep.flatten_hierarchy(returned_root_node)
    assert returned_steps != nil

    expected_step_ids = [lvl3.id, lvl2_fail_2.id, lvl2_fail.id, lvl2.id, lvl1.id, root_fail.id, root_step.id]
    assert length(returned_steps) == length(expected_step_ids)

    remaining_ids = Enum.reduce returned_steps, expected_step_ids, fn(returned_step, remaining_ids) ->
      assert returned_step != nil
      List.delete(remaining_ids, returned_step[:id])
    end
    assert length(remaining_ids) == 0
  end

end
