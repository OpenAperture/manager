defmodule DB.Queries.ProductDeploymentPlan.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlan
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlanStep
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlanStepOption
  alias ProjectOmeletteManager.DB.Queries.ProductDeploymentPlanStep, as: PDPSQuery

  setup_all _context do
    on_exit _context, fn ->
      Repo.delete_all(ProductDeploymentPlanStepOption)
      Repo.delete_all(ProductDeploymentPlanStep)
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    #[product: product, product2: product2, cluster: etcd_cluster, etcd_cluster2: etcd_cluster2, etcd_cluster3: etcd_cluster3, etcd_cluster4: etcd_cluster4]}
    {:ok, []}
  end

  #==============================
  # get_steps_for_plan tests

  test "get_steps_for_plan- no steps" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert

    returned_steps = Repo.all(PDPSQuery.get_steps_for_plan(plan.id))
    assert length(returned_steps) == 0
  end

  test "get_steps_for_plan- one step" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert
    step = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: plan.id, type: "build_component"}) |> Repo.insert

    returned_steps = Repo.all(PDPSQuery.get_steps_for_plan(plan.id))
    assert length(returned_steps) == 1
    returned_step = List.first(returned_steps)
    assert returned_step.id == step.id
  end

  test "get_steps_for_plan- multiple steps" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert
    step = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: plan.id, type: "build_component"}) |> Repo.insert
    step2 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: plan.id, type: "deploy_component"}) |> Repo.insert

    returned_steps = Repo.all(PDPSQuery.get_steps_for_plan(plan.id))
    assert length(returned_steps) == 2

    list_results = Enum.reduce returned_steps, [step.id, step2.id], fn(returned_step, remaining_steps) ->
      List.delete(remaining_steps, Map.from_struct(returned_step)[:id])
    end
    assert length(list_results) == 0
  end

  test "get_steps_for_plan- one step with one option" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert
    step = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: plan.id, type: "build_component"}) |> Repo.insert
    step_option = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert

    returned_steps = Repo.all(PDPSQuery.get_steps_for_plan(plan.id))
    assert length(returned_steps) == 1
    returned_step = hd(returned_steps)
    assert returned_step != nil

    list_results = Enum.reduce returned_steps, [step.id], fn(raw_step, remaining_steps) ->
      returned_step = Map.from_struct(raw_step)
      assert returned_step != nil

      returned_options = raw_step.product_deployment_plan_step_options
      assert returned_options != nil

      if (returned_step[:id] == step.id) do
        options_results = Enum.reduce returned_options, [step_option.id], fn(raw_option, remaining_options) ->
          List.delete(remaining_options, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0
      end
      List.delete(remaining_steps, returned_step[:id])
    end
    assert length(list_results) == 0
  end

  test "get_steps_for_plan- multiple steps with multiple options" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert
    step = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: plan.id, type: "build_component"}) |> Repo.insert
    step_option = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert
    step_option2 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert

    step2 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: plan.id, type: "build_component"}) |> Repo.insert
    step_option3 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step2.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert
    step_option4 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step2.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert

    step3 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: plan.id, type: "build_component"}) |> Repo.insert
    step_option5 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step3.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert
    step_option6 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step3.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert

    step4 = ProductDeploymentPlanStep.new(%{product_deployment_plan_id: plan.id, type: "build_component"}) |> Repo.insert
    step_option7 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step4.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert
    step_option8 = ProductDeploymentPlanStepOption.new(%{product_deployment_plan_step_id: step4.id, name: "#{UUID.uuid1()}", value: "something cool"}) |> Repo.insert


    returned_options = Repo.all(PDPSQuery.get_steps_for_plan(plan.id))
    assert length(returned_options) == 4
    returned_option = hd(returned_options)
    assert returned_option != nil

    list_results = Enum.reduce returned_options, [step.id, step2.id, step3.id, step4.id], fn(raw_option, remaining_options) ->
      returned_option = Map.from_struct(raw_option)
      assert returned_option != nil

      returned_options = raw_option.product_deployment_plan_step_options
      assert returned_options != nil

      if (returned_option[:id] == step.id) do
        options_results = Enum.reduce returned_options, [step_option.id, step_option2.id], fn(raw_option, remaining_options) ->
          List.delete(remaining_options, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0
      end

      if (returned_option[:id] == step2.id) do
        options_results = Enum.reduce returned_options, [step_option3.id, step_option4.id], fn(raw_option, remaining_options) ->
          List.delete(remaining_options, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0
      end

      if (returned_option[:id] == step3.id) do
        options_results = Enum.reduce returned_options, [step_option5.id, step_option6.id], fn(raw_option, remaining_options) ->
          List.delete(remaining_options, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0
      end

      if (returned_option[:id] == step4.id) do
        options_results = Enum.reduce returned_options, [step_option7.id, step_option8.id], fn(raw_option, remaining_options) ->
          List.delete(remaining_options, Map.from_struct(raw_option)[:id])
        end
        assert length(options_results) == 0
      end

      List.delete(remaining_options, returned_option[:id])
    end
    assert length(list_results) == 0
  end

end
