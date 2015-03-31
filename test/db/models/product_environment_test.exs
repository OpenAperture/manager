defmodule DB.Models.ProductEnvironment.Test do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable

  setup _context do
    product = Product.new(%{name: "ProductEnvironmentsModelsTest"}) |> Repo.insert

    on_exit _context, fn ->
      Repo.delete_all(ProductEnvironment)
      Repo.delete(product)
    end

    {:ok, [product: product]}
  end

  test "missing values fail validation" do
    changeset = ProductEnvironment.new(%{})
    
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :product_id)
    assert Keyword.has_key?(changeset.errors, :name)
  end

  test "bad product_id fails insert" do
    
    assert_raise Postgrex.Error,
                 "ERROR (foreign_key_violation): insert or update on table \"product_environments\" violates foreign key constraint \"product_environments_product_id_fkey\"",
                 fn -> ProductEnvironment.new(%{product_id: 98237834, name: "test"}) |> Repo.insert end
  end

  test "product_id and environment name combo must be unique", context do
    product = context[:product]
    env_vars = %{product_id: product.id, name: "test"}
    _env = ProductEnvironment.new(env_vars) |> Repo.insert
    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"product_environments_product_id_name_index\"",
                 fn -> ProductEnvironment.new(env_vars) |> Repo.insert end
  end

  test "belongs_to Product association", context do
    product = context[:product]
    
    pe = ProductEnvironment.new(%{product_id: product.id, name: "test"}) |> Repo.insert

    assert pe.product_id == product.id
    assert pe.name == "test"
    assert pe.id > 0

    # test association loads when we preload
    # Unforunately, Repo.get doesn't support preload (yet?),
    # So we need to do a Repo.all call.
    [loaded_env] = Repo.all(from env in ProductEnvironment,
                       where: env.id == ^pe.id,
                       preload: :product)

    assert loaded_env.product == product
  end

  test "retrieve associated product environmental variables", context do
    product = context[:product]
    product_environment = ProductEnvironment.new(%{product_id: product.id, name: "variable test"}) |> Repo.insert

    var1 = ProductEnvironmentalVariable.new(%{product_id: product.id, product_environment_id: product_environment.id, name: "A", value: "test"}) |> Repo.insert
    var2 = ProductEnvironmentalVariable.new(%{product_id: product.id, product_environment_id: product_environment.id, name: "B", value: "test"}) |> Repo.insert

    [product_environment] = Repo.all(from pe in ProductEnvironment,
                                     where: pe.id == ^product_environment.id,
                                     preload: :environmental_variables)

    assert length(product_environment.environmental_variables) == 2

    Repo.delete(var1)
    Repo.delete(var2)
  end

  test "validates that product name cannot be empty", context do
    product = context[:product]
    changeset = ProductEnvironment.new(%{product_id: product.id, name: ""})

    refute changeset.valid?

    changeset = ProductEnvironment.new(%{product_id: product.id, name: "some test name"})

    assert changeset.valid?
  end
end
