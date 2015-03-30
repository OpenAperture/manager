defmodule ProjectOmeletteManager.ProductEnvironmentsController.Test do
  use ExUnit.Case, async: false
  use Plug.Test
  use ProjectOmeletteManager.Test.ConnHelper

  import ProjectOmeletteManager.Router.Helpers

  alias ProjectOmeletteManager.Endpoint
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.Router

  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductEnvironment
  alias ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable
  
  setup_all do
    :meck.new(ProjectOmeletteManager.Plugs.Authentication, [:passthrough])
    :meck.expect(ProjectOmeletteManager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit fn -> :meck.unload end
  end

  setup do
    product = Product.new(%{name: "test_environments_product"})
              |> Repo.insert

    pe1 = ProductEnvironment.new(%{name: "test_environment_1", product_id: product.id})
          |> Repo.insert
    pe2 = ProductEnvironment.new(%{name: "test_environment_2", product_id: product.id})
          |> Repo.insert
    pev1 = ProductEnvironmentalVariable.new(%{name: "test_variable_1", product_id: product.id, product_environment_id: pe1.id})
           |> Repo.insert
    pev2 = ProductEnvironmentalVariable.new(%{name: "test_variable_2", product_id: product.id, product_environment_id: pe1.id})
           |> Repo.insert
    pev3 = ProductEnvironmentalVariable.new(%{name: "test_variable_3", product_id: product.id, product_environment_id: pe2.id})
           |> Repo.insert
    pev4 = ProductEnvironmentalVariable.new(%{name: "test_variable_4", product_id: product.id})
           |> Repo.insert

    on_exit fn ->
      Repo.delete_all(ProductEnvironmentalVariable)
      Repo.delete_all(ProductEnvironment)
      Repo.delete_all(Product)
    end

    {:ok, product: product, pe1: pe1, pe2: pe2, pev1: pev1, pev2: pev2, pev3: pev3, pev4: pev4}
  end

  test "index action -- success", context do
    product = context[:product]

    path = product_environments_path(Endpoint, :index, product.name)

    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2
  end
end