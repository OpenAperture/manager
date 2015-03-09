defmodule DB.Models.ProductDeploymentPlan.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlan

  setup _context do
    product = Repo.insert(%Product{name: "test plan"})
    product2 = Repo.insert(%Product{name: "test plan2"})

    on_exit _context, fn ->
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    {:ok, [product: product, product2: product2]}
  end

  test "validate - fail to create plan with missing values", context do
    plan   = %ProductDeploymentPlan{}
    result = ProductDeploymentPlan.validate(plan)

    assert map_size(result)    != 0
    assert result[:product_id] != nil
    assert result[:name]       != nil
  end

  test "validate - fail to create plan with missing name", context do
    plan   = %ProductDeploymentPlan{product_id: context[:product].id, }
    result = ProductDeploymentPlan.validate(plan)

    assert map_size(result) != 0
    assert result[:name] != nil
  end

  test "validate - create plan", context do
    plan   = %ProductDeploymentPlan{product_id: context[:product].id, name: "test plan"}
    result = ProductDeploymentPlan.validate(plan)

    assert is_nil(result)
  end

  test "create plan", context do
    plan = Repo.insert(%ProductDeploymentPlan{product_id: context[:product].id, name: "test plan"})
    retrieved = Repo.get(ProductDeploymentPlan, plan.id)

    assert retrieved == plan
  end
end
