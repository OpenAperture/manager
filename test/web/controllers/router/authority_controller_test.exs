defmodule OpenAperture.Manager.Controllers.Router.AuthorityController.Test do
  use ExUnit.Case, async: false
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  import Ecto.Query
  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.DB.Models.Router.Authority
  alias OpenAperture.Manager.DB.Models.Router.DeletedAuthority
  alias OpenAperture.Manager.DB.Models.Router.Route
  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Router

  setup do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    a1 = Repo.insert(%Authority{hostname: "test", port: 80})
    a2 = Repo.insert(%Authority{hostname: "test2", port: 80})

    Repo.insert(%Route{authority_id: a1.id, hostname: "test", port: 80})
    Repo.insert(%Route{authority_id: a1.id, hostname: "test2", port: 80})

    on_exit fn ->
      Repo.delete_all(DeletedAuthority)
      Repo.delete_all(Route)
      Repo.delete_all(Authority)

      try do
        :meck.unload(OpenAperture.Manager.Plugs.Authentication)
      rescue _ -> IO.puts "" end
    end

    {:ok, authorities: [a1, a2]}
  end

   test "GET /router/authorities with query param (url uppercase encoded)", context do
    a1 = List.first(context[:authorities])
    path = authority_path(Endpoint, :index)
    conn = call(Router, :get, path, hostspec: "#{a1.hostname}%3A#{a1.port}")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert body["hostname"] == a1.hostname
    assert body["port"] == a1.port
  end

  test "GET /router/authorities with query param (url lowercase encoded)", context do
    a1 = List.first(context[:authorities])
    path = authority_path(Endpoint, :index, hostspec: "#{a1.hostname}%3a#{a1.port}")
    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert body["hostname"] == a1.hostname
    assert body["port"] == a1.port
  end

  test "GET /router/authorities with query param (not url encoded)", context do
    a1 = List.first(context[:authorities])
    path = authority_path(Endpoint, :index, hostspec: "#{a1.hostname}:#{a1.port}")
    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert body["hostname"] == a1.hostname
    assert body["port"] == a1.port
  end

  test "GET /router/authorities with query param for non-existent host" do
    path = authority_path(Endpoint, :index, hostspec: "not_a_real_host:9999")
    conn = call(Router, :get, path)

    assert conn.status == 404
  end

  test "GET /router/authorities with invalied query param" do
    path = authority_path(Endpoint, :index, hostspec: "hostname^9999")
    conn = call(Router, :get, path)

    assert conn.status == 400
  end

  test "GET /router/authorities", context do
    path = authority_path(Endpoint, :index)
    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert length(body) == length(context[:authorities])
  end

  test "GET /router/authorities/1", context do
    a1 = List.first(context[:authorities])

    path = authority_path(Endpoint, :show, a1.id)
    conn = call(Router, :get, path)

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert body["hostname"] == a1.hostname
    assert body["port"] == a1.port
  end

  test "GET /router/authorities/:id id not found" do
    path = authority_path(Endpoint, :show, 1234567890)
    conn = call(Router, :get, path)

    assert conn.status == 404
  end

  test "DELETE /router/authorities/1", context do
    a1 = List.first(context[:authorities])

    path = authority_path(Endpoint, :delete, a1.id)
    conn = call(Router, :delete, path)

    assert conn.status == 204

    assert Authority |> Repo.all |> length == length(context[:authorities]) - 1
  end

  test "DELETE /router/authorities/1 deletes associated routes", context do
    routes_count = length(Repo.all(Route))

    a1 = List.first(context[:authorities])

    path = authority_path(Endpoint, :delete, a1.id)
    conn = call(Router, :delete, path)

    assert conn.status == 204

    assert length(Repo.all(Route)) == routes_count - 2
  end

  test "DELETE /router/authorities/1 creates a record in the deleted_authorities table", context do
    a1 = List.first(context[:authorities])

    deleted_count = DeletedAuthority |> Repo.all |> length

    path = authority_path(Endpoint, :delete, a1.id)
    conn = call(Router, :delete, path)

    assert conn.status == 204

    deleted = DeletedAuthority
              |> where([da], da.hostname == ^a1.hostname)
              |> where([da], da.port == ^a1.port)
              |> Repo.one

    assert DeletedAuthority |> Repo.all |> length == deleted_count + 1

    assert deleted != nil
    assert deleted.hostname == a1.hostname
    assert deleted.port == a1.port
  end

  test "DELETE /router/authorities/123456789" do
    path = authority_path(Endpoint, :delete, 123456789)
    conn = call(Router, :delete, path)

    assert conn.status == 404
  end

  test "DELETE /router/authorities/bad_authority_id" do
    path = authority_path(Endpoint, :delete, "bad_authority_id")
    conn = call(Router, :delete, path)

    assert conn.status == 404
  end

  test "POST /router/authorities" do
    authority = %{hostname: "new_test", port: 80}
    path = authority_path(Endpoint, :create)
    conn = call(Router, :post, path, authority)

    assert conn.status == 201
    assert List.keymember?(conn.resp_headers, "location", 0)
    {_, location} = List.keyfind(conn.resp_headers, "location", 0)
    assert Regex.match?(~r/router\/authorities\/\d+/, location)
  end

  test "POST /router/authorities, missing hostname" do
    authority = %{port: 80}
    path = authority_path(Endpoint, :create)
    conn = call(Router, :post, path, authority)

    assert conn.status == 400
  end

  test "POST /router/authorities, missing port" do
    authority = %{hostname: "new_test"}
    path = authority_path(Endpoint, :create)
    conn = call(Router, :post, path, authority)

    assert conn.status == 400
  end

  test "POST /router/authorities, bad port value" do
    authority = %{hostname: "new_test", port: "NaN"}
    path = authority_path(Endpoint, :create)
    conn = call(Router, :post, path, authority)

    assert conn.status == 400
  end

  test "POST /router/authorities, port number out of range" do
    authority = %{hostname: "new_test", port: "99999"}
    path = authority_path(Endpoint, :create)
    conn = call(Router, :post, path, authority)

    assert conn.status == 400
  end

  test "POST /router/authorities, authority already exists", context do
    a1 = List.first(context[:authorities])
    authority = %{hostname: a1.hostname, port: a1.port}
    path = authority_path(Endpoint, :create)
    conn = call(Router, :post, path, authority)

    assert conn.status == 409
  end

  test "PUT /router/authorities/:id", context do
    a1 = List.first(context[:authorities])
    new_port = 1337
    authority = %{hostname: a1.hostname, port: new_port}

    path = authority_path(Endpoint, :update, a1.id)
    conn = call(Router, :put, path, authority)

    assert conn.status == 204

    new_a1 = Repo.get(Authority, a1.id)
    assert new_a1.port == new_port
  end

  test "PUT /router/authorities/:id creates a DeletedAuthority for the old hostname:port combo", context do
    deleted_count = DeletedAuthority |> Repo.all |> length

    a1 = List.first(context[:authorities])
    new_port = 1337
    authority = %{hostname: a1.hostname, port: new_port}

    path = authority_path(Endpoint, :update, a1.id)
    conn = call(Router, :put, path, authority)

    assert conn.status == 204

    new_a1 = Repo.get(Authority, a1.id)
    assert new_a1.port == new_port
    
    deleted = Repo.all(DeletedAuthority)
    assert length(deleted) == deleted_count + 1
    
    da = List.first(deleted)
    assert da.hostname == a1.hostname
    assert da.port == a1.port
  end

  test "PUT /router/authorities/:id id not found", context do
    a1 = List.first(context[:authorities])
    new_port = 1337
    authority = %{hostname: a1.hostname, port: new_port}

    path = authority_path(Endpoint, :update, 1234567890)
    conn = call(Router, :put, path, authority)
    
    assert conn.status == 404
  end

  test "PUT /router/authorities/:id invalid id", context do
    a1 = List.first(context[:authorities])
    new_port = 1337
    authority = %{hostname: a1.hostname, port: new_port}

    path = authority_path(Endpoint, :update, "not_a_valid_id")
    conn = call(Router, :put, path, authority)
    
    assert conn.status == 404
  end

  test "PUT /router/authorities/:id conflict", context do
    a1 = List.first(context[:authorities])
    a2 = List.last(context[:authorities])
    authority = %{hostname: a2.hostname, port: a1.port}

    path = authority_path(Endpoint, :update, a1.id)
    conn = call(Router, :put, path, authority)
    
    assert conn.status == 409
  end

  test "PUT /router/authorities/:id empty hostname", context do
    a1 = List.first(context[:authorities])

    authority = %{hostname: ""}

    path = authority_path(Endpoint, :update, a1.id)
    conn = call(Router, :put, path, authority)
    
    assert conn.status == 400
  end

  test "PUT /router/authorities/:id bad hostname value", context do
    a1 = List.first(context[:authorities])

    authority = %{hostname: 1234567890}

    path = authority_path(Endpoint, :update, a1.id)
    conn = call(Router, :put, path, authority)
    
    assert conn.status == 400
  end

  test "PUT /router/authorities/:id empty port value", context do
    a1 = List.first(context[:authorities])

    authority = %{port: ""}

    path = authority_path(Endpoint, :update, a1.id)
    conn = call(Router, :put, path, authority)
    
    assert conn.status == 400
  end

  test "PUT /router/authorities/:id bad port value", context do
    a1 = List.first(context[:authorities])

    authority = %{port: "not a parseable number"}

    path = authority_path(Endpoint, :update, a1.id)
    conn = call(Router, :put, path, authority)
    
    assert conn.status == 400
  end
end