defmodule DB.Queries.ProductDeploymentPlan.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan
  alias OpenAperture.Manager.DB.Queries.ProductDeploymentPlan, as: PDPQuery

  setup_all _context do
    on_exit _context, fn ->
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    #[product: product, product2: product2, cluster: etcd_cluster, etcd_cluster2: etcd_cluster2, etcd_cluster3: etcd_cluster3, etcd_cluster4: etcd_cluster4]}
    {:ok, []}
  end

  #==============================
  # get_deployment_plans_for_product tests

  test "get_deployment_plans_for_product- no plans" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    
    returned_plans = Repo.all(PDPQuery.get_deployment_plans_for_product(product.id))
    assert length(returned_plans) == 0
  end

  test "get_deployment_plans_for_product- one plan" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert

    returned_plans = Repo.all(PDPQuery.get_deployment_plans_for_product(product.id))
    assert length(returned_plans) == 1
    returned_plan = hd(returned_plans)
    assert returned_plan.id == plan.id
  end

  test "get_deployment_plans_for_product- multiple plans" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan2 = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert

    returned_plans = Repo.all(PDPQuery.get_deployment_plans_for_product(product.id))
    assert length(returned_plans) == 2

    list_results = Enum.reduce returned_plans, [plan.id, plan2.id], fn(returned_plan, remaining_plans) -> 
      List.delete(remaining_plans, Map.from_struct(returned_plan)[:id])
    end
    assert length(list_results) == 0
  end

  test "get_deployment_plan_by_name- one plan" do
    product = Product.new(%{name: "#{UUID.uuid1()}"}) |> Repo.insert
    plan = ProductDeploymentPlan.new(%{product_id: product.id, name: "#{UUID.uuid1()}"}) |> Repo.insert

    returned_plans = Repo.all(PDPQuery.get_deployment_plan_by_name(product.id, plan.name))
    assert length(returned_plans) == 1
    returned_plan = hd(returned_plans)
    assert returned_plan.id == plan.id
    assert returned_plan.name == plan.name
  end  
end