defmodule DB.Models.ProductDeploymentPlan.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductDeploymentPlan

  setup _context do
    {:ok, product} = Product.vinsert(%{name: "test plan"})
    {:ok, product2} = Product.vinsert(%{name: "test plan2"})

    on_exit _context, fn ->
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    {:ok, [product: product, product2: product2]}
  end

  test "validate - fail to create plan with missing values" do
    {status, errors} = ProductDeploymentPlan.vinsert(%{})

    assert status == :error
    assert Keyword.has_key?(errors, :product_id)
    assert Keyword.has_key?(errors, :name)
  end

  test "validate - create plan", context do
    {status, _plan} = ProductDeploymentPlan.vinsert(%{product_id: context[:product].id, name: "test plan"})
    assert status == :ok
  end

  test "create plan", context do
    {:ok, plan} = ProductDeploymentPlan.vinsert(%{product_id: context[:product].id, name: "test plan"})
    retrieved = Repo.get(ProductDeploymentPlan, plan.id)

    assert retrieved == plan
  end
end
