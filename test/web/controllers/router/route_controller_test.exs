defmodule OpenAperture.Manager.Controllers.Router.RouteController.Test do
  use ExUnit.Case, async: false
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  import OpenAperture.Manager.Router.Helpers

  alias OpenAperture.Manager.DB.Models.Router.Authority
  alias OpenAperture.Manager.DB.Models.Router.Route
  alias OpenAperture.Manager.Endpoint
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.Router

  setup do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    a1 = Repo.insert(%Authority{hostname: "test", port: 80})
    a2 = Repo.insert(%Authority{hostname: "test2", port: 80})

    route1 = Repo.insert(%Route{authority_id: a1.id, hostname: "east.test", port: 80})
    route2 = Repo.insert(%Route{authority_id: a1.id, hostname: "west.test", port: 80})

    on_exit fn ->
      Repo.delete_all(Route)
      Repo.delete_all(Authority)

      try do
        :meck.unload(OpenAperture.Manager.Plugs.Authentication)
      rescue _ -> IO.puts "" end
    end

    {:ok, a1: a1, a2: a2, route1: route1, route2: route2}
  end

  test "GET /api/authorities/:authority_id/routes?hostspec=... (not url encoded)", context do
    route = context[:route1]
    a1 = context[:a1]

    path = route_path(Endpoint, :index, a1.id, hostspec: "#{route.hostname}:#{route.port}")
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert body["hostname"] == route.hostname
    assert body["port"] == route.port
  end

  test "GET /api/authorities/:authority_id/routes?hostspec=... (url uppercase encoded)", context do
    route = context[:route1]
    a1 = context[:a1]

    path = route_path(Endpoint, :index, a1.id, hostspec: "#{route.hostname}%3A#{route.port}")
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert body["hostname"] == route.hostname
    assert body["port"] == route.port
  end

  test "GET /api/authorities/:authority_id/routes?hostspec=... (url lowercase encoded)", context do
    route = context[:route1]
    a1 = context[:a1]

    path = route_path(Endpoint, :index, a1.id, hostspec: "#{route.hostname}%3a#{route.port}")
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert body["hostname"] == route.hostname
    assert body["port"] == route.port
  end

  test "GET /api/authorities/:authority_id/routes?hostspec=... (invalid hostspec param)", context do
    route = context[:route1]
    a1 = context[:a1]

    path = route_path(Endpoint, :index, a1.id, hostspec: "#{route.hostname}^#{route.port}")
    conn = call(Router, :get, path)

    assert conn.status == 400
  end

  test "GET /api/authorities/:authority_id/routes?hostspec=... (route not found)", context do
    a1 = context[:a1]

    path = route_path(Endpoint, :index, a1.id, hostspec: "bad_hostname:80")
    conn = call(Router, :get, path)

    assert conn.status == 404
  end

  test "GET /api/authorities/:authority_id/routes?hostspec=... (authority not found)", context do
    route = context[:route1]

    path = route_path(Endpoint, :index, 123456789, hostspec: "#{route.hostname}:#{route.port}")
    conn = call(Router, :get, path)

    assert conn.status == 404
  end

  test "GET /api/authorities/:authority_id/routes", context do
    a1 = context[:a1]

    path = route_path(Endpoint, :index, a1.id)
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 2
  end

  test "GET /api/authorities/:authority_id/routes for authority with no routes", context do
    a2 = context[:a2]

    path = route_path(Endpoint, :index, a2.id)
    conn = call(Router, :get, path)

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert length(body) == 0
  end

  test "DELETE /api/authorities/:authority_id/routes/clear", context do
    route_count = Route |> Repo.all |> length

    a1 = context[:a1]

    path = route_path(Endpoint, :clear, a1.id)
    conn = call(Router, :delete, path)

    assert conn.status == 204

    assert Route |> Repo.all |> length == route_count - 2
  end

  test "DELETE /api/authorities/:authority_id/routes/clear -- authority not found" do
    route_count = Route |> Repo.all |> length

    path = route_path(Endpoint, :clear, 1234567890)
    conn = call(Router, :delete, path)

    assert conn.status == 404

    assert Route |> Repo.all |> length == route_count
  end

  test "DELETE /api/authorities/:authority_id/routes/clear updates authority's updated_at timestamp", context do
    a1 = context[:a1]
    timestamp = a1.updated_at

    :timer.sleep(1000)

    path = route_path(Endpoint, :clear, a1.id)
    conn = call(Router, :delete, path)

    assert conn.status == 204

    a1 = Repo.get(Authority, a1.id)

    assert a1.updated_at > timestamp
  end

  test "DELETE /api/authorities/:authority_id/routes/:id", context do
    route1 = context[:route1]
    route_count = Route |> Repo.all |> length

    path = route_path(Endpoint, :delete, route1.authority_id, route1.id)
    conn = call(Router, :delete, path)

    assert conn.status == 204

    assert Route |> Repo.all |> length == route_count - 1
  end

  test "DELETE /api/authorities/:authority_id/routes/:id updates authority's updated_at timestamp", context do
    route1 = context[:route1]
    a1 = context[:a1]
    timestamp = a1.updated_at

    :timer.sleep(1000)

    path = route_path(Endpoint, :delete, route1.authority_id, route1.id)
    conn = call(Router, :delete, path)

    assert conn.status == 204

    a1 = Repo.get(Authority, a1.id)
    assert a1.updated_at > timestamp
  end

  test "DELETE /api/authorities/:authority_id/routes/:id route id not found", context do
    a1 = context[:a1]
    route_count = Route |> Repo.all |> length

    path = route_path(Endpoint, :delete, a1.id, 1234567890)
    conn = call(Router, :delete, path)

    assert conn.status == 404

    assert Route |> Repo.all |> length == route_count
  end

  test "DELETE /api/authorities/:authority_id/routes/:id authority id not found", context do
    route1 = context[:route1]
    route_count = Route |> Repo.all |> length

    path = route_path(Endpoint, :delete, 1234567890, route1.id)
    conn = call(Router, :delete, path)

    assert conn.status == 404

    assert Route |> Repo.all |> length == route_count
  end

  test "POST /api/authorities/:authority_id/routes", context do
    a1 = context[:a1]

    route = %{hostname: "staging.test", port: 80}

    path = route_path(Endpoint, :create, a1.id)
    conn = call(Router, :post, path, route)

    assert conn.status == 201
    assert List.keymember?(conn.resp_headers, "location", 0)
    {_, location} = List.keyfind(conn.resp_headers, "location", 0)
    assert Regex.match?(~r/router\/authorities\/#{a1.id}\/routes\/\d+/, location)
  end

  test "POST /api/authorities/:authority_id/routes updates authority's updated_at timestamp", context do
    a1 = context[:a1]
    timestamp = a1.updated_at

    route = %{hostname: "staging.test", port: 80}

    :timer.sleep(1000)

    path = route_path(Endpoint, :create, a1.id)
    conn = call(Router, :post, path, route)

    assert conn.status == 201
    a1 = Repo.get(Authority, a1.id)

    assert a1.updated_at > timestamp
  end

  test "POST /api/authorities/:authority_id/routes -- authority not found" do
    route = %{hostname: "staging.test", port: 80}

    path = route_path(Endpoint, :create, 1234567890)
    conn = call(Router, :post, path, route)

    assert conn.status == 404
  end

  test "POST /api/authorities/:authority_id/routes -- conflict", context do
    route1 = context[:route1]

    route = %{hostname: route1.hostname, port: route1.port}

    path = route_path(Endpoint, :create, route1.authority_id)
    conn = call(Router, :post, path, route)

    assert conn.status == 409
  end

  test "POST /api/authorities/:authority_id/routes -- missing hostname", context do
    a1 = context[:a1]
    route = %{port: 1234}

    path = route_path(Endpoint, :create, a1.id)
    conn = call(Router, :post, path, route)

    assert conn.status == 400
  end

  test "POST /api/authorities/:authority_id/routes -- missing port", context do
    a1 = context[:a1]
    route = %{hostname: "new_test"}

    path = route_path(Endpoint, :create, a1.id)
    conn = call(Router, :post, path, route)

    assert conn.status == 400
  end

  test "POST /api/authorities/:authority_id/routes -- validated port number", context do
    a1 = context[:a1]
    route = %{hostname: "new_test", port: 99999}

    path = route_path(Endpoint, :create, a1.id)
    conn = call(Router, :post, path, route)

    assert conn.status == 400
  end

  test "POST /api/authorities/:authority_id/routes -- validates hostname", context do
    a1 = context[:a1]
    route = %{hostname: 1234, port: 1234}

    path = route_path(Endpoint, :create, a1.id)
    conn = call(Router, :post, path, route)

    assert conn.status == 400
  end

  test "PUT /api/authorities/:authority_id/routes/:id", context do
    route1 = context[:route1]
    updated_route = %{hostname: "test_updated"}

    path = route_path(Endpoint, :update, route1.authority_id, route1.id)
    conn = call(Router, :put, path, updated_route)

    assert conn.status == 204

    route = Repo.get(Route, route1.id)
    assert route.hostname == "test_updated"
  end

  test "PUT /api/authorities/:authority_id/routes/:id updated authority's updated_at timestamp", context do
    a1 = context[:a1]
    timestamp = a1.updated_at
    route1 = context[:route1]

    :timer.sleep(1000)

    updated_route = %{hostname: "test_updated"}
    path = route_path(Endpoint, :update, route1.authority_id, route1.id)
    conn = call(Router, :put, path, updated_route)

    assert conn.status == 204

    a1 = Repo.get(Authority, a1.id)
    assert a1.updated_at > timestamp
  end

  test "PUT /api/authorities/:authority_id/routes/:id -- bad authority id", context do
    route1 = context[:route1]
    updated_route = %{hostname: "test_updated"}

    path = route_path(Endpoint, :update, 1234567890, route1.id)
    conn = call(Router, :put, path, updated_route)

    assert conn.status == 404
  end

  test "PUT /api/authorities/:authority_id/routes/:id -- bad route id", context do
    route1 = context[:route1]
    updated_route = %{hostname: "test_updated"}

    path = route_path(Endpoint, :update, route1.authority_id, 1234567890)
    conn = call(Router, :put, path, updated_route)

    assert conn.status == 404
  end

  test "PUT /api/authorities/:authority_id/routes/:id bad updated hostname", context do
    route1 = context[:route1]
    updated_route = %{hostname: 1234}

    path = route_path(Endpoint, :update, route1.authority_id, route1.id)
    conn = call(Router, :put, path, updated_route)

    assert conn.status == 400
  end

  test "PUT /api/authorities/:authority_id/routes/:id bad updated port", context do
    route1 = context[:route1]
    updated_route = %{port: 99999}

    path = route_path(Endpoint, :update, route1.authority_id, route1.id)
    conn = call(Router, :put, path, updated_route)

    assert conn.status == 400
  end

  test "PUT /api/authorities/:authority_id/routes/:id conflict with existing route", context do
    route1 = context[:route1]
    route2 = context[:route2]
    updated_route = %{hostname: route2.hostname, port: route2.port}

    path = route_path(Endpoint, :update, route1.authority_id, route1.id)
    conn = call(Router, :put, path, updated_route)

    assert conn.status == 409
  end
end