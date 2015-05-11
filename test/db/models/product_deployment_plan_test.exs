defmodule DB.Models.ProductDeploymentPlan.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductDeploymentPlan

  setup _context do
    product = Product.new(%{name: "test plan"}) |> Repo.insert
    product2 = Product.new(%{name: "test plan2"}) |> Repo.insert

    on_exit _context, fn ->
      Repo.delete_all(ProductDeploymentPlan)
      Repo.delete_all(Product)
    end

    {:ok, [product: product, product2: product2]}
  end

  test "validate - fail to create plan with missing values" do
    changeset = ProductDeploymentPlan.new(%{})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :product_id)
    assert Keyword.has_key?(changeset.errors, :name)
  end

  test "validate - create plan", context do
    plan = ProductDeploymentPlan.new(%{product_id: context[:product].id, name: "test plan"}) |> Repo.insert
    assert plan != nil
  end

  test "create plan", context do
    plan = ProductDeploymentPlan.new(%{product_id: context[:product].id, name: "test plan"}) |> Repo.insert
    retrieved = Repo.get(ProductDeploymentPlan, plan.id)

    assert retrieved == plan
  end
end
