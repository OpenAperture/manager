defmodule OpenAperture.Manager.Controllers.ProductsTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  alias OpenAperture.Manager.DB.Models.Product

  setup_all _context do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)
    :meck.new OpenAperture.Manager.Repo

    on_exit _context, fn ->
      :meck.unload
    end    
    :ok
  end

  @endpoint OpenAperture.Manager.Endpoint

  test "index action" do
    products = [%Product{name: "test1"}, %Product{name: "test2"}]
    :meck.expect(OpenAperture.Manager.Repo, :all, 1, products)

    conn = get conn(), "/products"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2

    assert Enum.any?(body, &(&1["name"] == "test1"))
    assert Enum.any?(body, &(&1["name"] == "test2"))
  end

  test "show action - found" do
    product = %Product{name: "test1"}
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, product)

    conn = get conn(), "/products/test1"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["name"] == "test1"
  end

  test "show action -- not found" do
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, nil)

    conn = get conn(), "/products/test1"

    assert conn.status == 404
  end

  test "create action -- success" do
    product = %Product{name: "test1", id: 1}
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, nil)
    :meck.expect(OpenAperture.Manager.Repo, :insert, 1, product)

    conn = post conn(), "/products", %{name: "test1"}

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/products/test1" == location
  end

  test "create action -- fails on conflict" do
    product = %Product{name: "test1", id: 1}
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, product)

    conn = post conn(), "/products", %{name: "test1"}

    assert conn.status == 409
  end

  test "create action -- bad request on invalid product name" do
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, nil)

    conn = post conn(), "/products", %{name: ""}

    assert conn.status == 400
  end

  test "delete action -- success" do
    product = %Product{name: "test1", id: 1}
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, product)
    :meck.expect(OpenAperture.Manager.Repo, :delete!, 1, product)
    :meck.expect(OpenAperture.Manager.Repo, :all, 1, [])
    :meck.expect(OpenAperture.Manager.Repo, :delete_all, 1, nil)
    :meck.expect(OpenAperture.Manager.Repo, :transaction, fn fun -> fun.(); {:ok, nil} end)

    conn = delete conn(), "/products/test1"

    assert conn.status == 204
  end

  test "delete action -- not found" do
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, nil)

    conn = delete conn(), "/products/test1"

    assert conn.status == 404
  end

  test "update action -- success" do
    product = %Product{name: "original_test1", id: 1}
    updated_product = %Product{name: "updated_test1", id: 1}
    :meck.expect(OpenAperture.Manager.Repo, :one, fn query ->

      # No real good way to get at the structure of the query, so just look at
      # the string generated by Kernel.inspect/1 and see if it's for the first
      # check or the second check.
      res = query
            |> inspect
            |> String.contains?("original_test1")

      if res, do: product, else: nil
    end)

    :meck.expect(OpenAperture.Manager.Repo, :update, 1, updated_product)

    conn = put conn(), "/products/original_test1", %{name: "updated_test1"}

    assert conn.status == 204

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/products/updated_test1" == location
  end

  test "update action -- not found" do
    :meck.expect(OpenAperture.Manager.Repo, :one, 1, nil)

    conn = put conn(), "/products/test1", %{name: "updated_test1"}

    assert conn.status == 404
  end

  test "update action -- fails on invalid change" do
    product = %Product{name: "original_test1", id: 1}
    :meck.expect(OpenAperture.Manager.Repo, :one, fn query ->

      # No real good way to get at the structure of the query, so just look at
      # the string generated by Kernel.inspect/1 and see if it's for the first
      # check or the second check.
      res = query
            |> inspect
            |> String.contains?("original_test1")

      if res, do: product, else: nil
    end)

    conn = put conn(), "/products/original_test1", %{name: ""}

    assert conn.status == 400
  end

  test "update action -- fails on conflicting name" do
    product1 = %Product{name: "original_test1", id: 1}
    product2 = %Product{name: "updated_test1", id: 2}

    :meck.expect(OpenAperture.Manager.Repo, :one, fn query ->

      # No real good way to get at the structure of the query, so just look at
      # the string generated by Kernel.inspect/1 and see if it's for the first
      # check or the second check.
      res = query
            |> inspect
            |> String.contains?("original_test1")

      if res, do: product1, else: product2
    end)

    conn = put conn(), "/products/original_test1", %{name: ""}

    assert conn.status == 400
  end
end