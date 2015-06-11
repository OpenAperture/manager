defmodule OpenAperture.Manager.Controllers.ProductClustersTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductCluster

  setup_all _context do
    :meck.new OpenAperture.Manager.Repo
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit _context, fn ->
      try do
        :meck.unload(OpenAperture.Manager.Plugs.Authentication)
        :meck.unload
      rescue _ -> IO.puts "" end
    end    
    :ok
  end

  @endpoint OpenAperture.Manager.Endpoint 

  test "index action -- product exists" do
    product = %Product{name: "test1", id: 1}
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, product)

    clusters = [%ProductCluster{product_id: product.id}, %ProductCluster{product_id: product.id}]

    :meck.expect(OpenAperture.Manager.Repo, :all, 1, clusters)

    conn = get conn(), "/products/test1/clusters"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2

    assert Enum.all?(body, &(&1["product_id"] == product.id))
  end

  test "index action -- product exists but no associated clusters" do
    product = %Product{name: "test1", id: 1}
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, product)

    :meck.expect(OpenAperture.Manager.Repo, :all, 1, [])

    conn = get conn(), "/products/test1/clusters"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "index action -- product does not exist" do
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, nil)

    conn = get conn(), "products/test1/clusters"

    assert conn.status == 404
  end

  test "create action -- success" do
    product = %Product{name: "test1", id: 1}

    :meck.expect(OpenAperture.Manager.Repo, :one, 1, product)
    :meck.expect(OpenAperture.Manager.Repo, :all, 1, [1, 2, 3])
    :meck.expect(OpenAperture.Manager.Repo, :delete_all, 1, 0)
    :meck.expect(OpenAperture.Manager.Repo, :transaction, 1, {:ok, :ok})

    conn = post conn(), "products/test1/clusters", %{clusters: [%{id: 1}, %{id: 2}, %{id: 3}]}

    assert conn.status == 201
  end

  test "create action -- product not found" do
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, nil)

    conn = post conn(), "products/test1/clusters", %{clusters: [%{id: 1}, %{id: 2}]}

    assert conn.status == 404
  end

  test "create action -- invalid etcd cluster ids provided" do
    product = %Product{name: "test1", id: 1}

    :meck.expect(OpenAperture.Manager.Repo, :one, 1, product)
    :meck.expect(OpenAperture.Manager.Repo, :all, 1, [1, 2])

    conn = post conn(), "products/test1/clusters", %{clusters: [%{id: 1}, %{id: 2}, %{id: 3}]}

    assert conn.status == 400
  end

  test "destroy action -- success" do
    product = %Product{name: "test1", id: 1}

    :meck.expect(OpenAperture.Manager.Repo, :one, 1, product)
    :meck.expect(OpenAperture.Manager.Repo, :delete_all, 1, 1)
    :meck.expect(OpenAperture.Manager.Repo, :delete, 1, 1)
    :meck.expect(OpenAperture.Manager.Repo, :all, 1, [])

    conn = delete conn(), "products/test1/clusters"

    assert conn.status == 204
  end

  test "destroy action -- product not found" do
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, nil)

    conn = delete conn(), "products/test1/clusters"

    assert conn.status == 404
  end
end