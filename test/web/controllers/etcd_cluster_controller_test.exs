defmodule ProjectOmeletteManager.EtcdClusterController.Test do
  use ExUnit.Case
  use Plug.Test
  use ProjectOmeletteManager.Test.ConnHelper

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Queries.EtcdCluster, as: EtcdClusterQuery
  alias ProjectOmeletteManager.Router

  setup do
    :meck.new ProjectOmeletteManager.Repo

    on_exit fn -> :meck.unload end
  end

  test "index" do
    clusters = [%EtcdCluster{etcd_token: "abc123"}]
    :meck.expect(ProjectOmeletteManager.Repo, :all, 1, clusters)
    conn = call(Router, :get, "/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 1
    cluster = List.first(body)

    assert cluster["etcd_token"] == "abc123"
  end

  test "index returns empty list if no clusters" do
    :meck.expect(ProjectOmeletteManager.Repo, :all, 1, [])
    conn = call(Router, :get, "/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "show returns 404 if a matching cluster wasn't found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token")

    assert conn.status == 404
  end

  test "show returns the matched etcd cluster" do
    cluster = %EtcdCluster{etcd_token: "abc123"}
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, cluster)

    conn = call(Router, :get, "/clusters/some_etcd_token")

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    assert body["etcd_token"] == "abc123"
  end

  test "register action - bad request if no etcd_token is provided" do
    conn = call(Router, :post, "/clusters", Poison.encode!(%{}), [headers: [{"content-type", "application/json"}]])

    assert conn.status == 400

    body = Poison.decode!(conn.resp_body)

    assert body == %{"etcd_token" => "required"}
  end

  test "register action -- success" do
    cluster = %EtcdCluster{id: 1, etcd_token: "token"}
    :meck.expect(Repo, :insert, 1, cluster)
    conn = call(Router, :post, "/clusters", Poison.encode!(cluster), [headers: [{"content-type", "application/json"}]])

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)
    location_header = List.keyfind(conn.resp_headers, "location", 0)

    assert location_header == {"location", "/clusters/token"}
  end

  test "destroy action -- not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :delete, "/clusters/some_etcd_token")

    assert conn.status == 404
  end

  test "destroy action -- success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, %EtcdCluster{id: 1, etcd_token: "some_etcd_token"})
    :meck.expect(Repo, :delete, 1, 1)

    conn = call(Router, :delete, "/clusters/some_etcd_token")

    assert conn.status == 204
  end

  #==========
  # products

  test "associated products" do
    cluster = %EtcdCluster{etcd_token: "#{UUID.uuid1()}"}
    products = [
      %Product{name: "test product3"},
      %Product{name: "test product4"}
    ]
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, cluster)
    :meck.expect(Repo, :all, 1, products)

    conn = call(Router, :get, "/clusters/#{cluster.etcd_token}/products")

    assert conn.status == 200

    resp_products = Poison.decode!(conn.resp_body)
    assert length(resp_products) == 2

    # round-trip the products list to json-ify it
    products
    |> Poison.encode!
    |> Poison.decode!
    |> Enum.each(fn product -> assert product in resp_products end)
  end

  test "no associated products" do
    cluster = %EtcdCluster{etcd_token: "#{UUID.uuid1()}"}
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, cluster)
    :meck.expect(Repo, :all, 1, [])

    conn = call(Router, :get, "/clusters/#{cluster.etcd_token}/products")

    assert conn.status == 200

    resp_products = Poison.decode!(conn.resp_body)
    assert length(resp_products) == 0
  end

  test "associated products to invalid etcd token results in 404" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/products")

    assert conn.status == 404
  end

  # #=========
  # # tests for machines
  # test "get machines success" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> [] end)

  #   conn = Router.call(conn("GET", "clusters/abc123/machines", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 200
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  # end

  test "get machines not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/machines")

    assert conn.status == 404
  end

  # test "get machines fail" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> nil end)

  #   conn = Router.call(conn("GET", "clusters/abc123/machines", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 500
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  # end

  # #=========
  # # tests for units
  # test "get units success" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> [] end)

  #   conn = Router.call(conn("GET", "clusters/abc123/units", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 200
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  # end

  test "get units not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/units")

    assert conn.status == 404
  end

  # test "get units fail" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> nil end)

  #   conn = Router.call(conn("GET", "clusters/abc123/units", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 500
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  # end

  # #=========
  # # tests for units_state
  # test "get units_state success" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units_state, fn token -> [] end)

  #   conn = Router.call(conn("GET", "clusters/abc123/state", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 200
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  # end

  test "get units_state not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/state")

    assert conn.status == 404
  end

  # test "get units_state fail" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units_state, fn token -> nil end)

  #   conn = Router.call(conn("GET", "clusters/abc123/state", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 500
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  # end

  # #=========
  # # tests for unit_logs
  # test "get unit_logs success" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)

  #   host = Map.put(%{}, "id", "123")
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> [host] end)

  #   unit = Map.put(%{}, "name", "test")
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> [unit] end)

  #   :meck.new(CloudosBuildServer.Agents.SystemdUnit, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.SystemdUnit, :execute_journal_request, fn hosts, unit, verify_result -> {:ok, "happy result", ""} end)


  #   conn = Router.call(conn("GET", "clusters/abc123/machines/123/units/test/logs", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 200
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  #   :meck.unload(CloudosBuildServer.Agents.SystemdUnit)
  # end

  # test "get unit_logs retrieve log error" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)

  #   host = Map.put(%{}, "id", "123")
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> [host] end)

  #   unit = Map.put(%{}, "name", "test")
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> [unit] end)

  #   :meck.new(CloudosBuildServer.Agents.SystemdUnit, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.SystemdUnit, :execute_journal_request, fn hosts, unit, verify_result -> {:error, "bad news bears", ""} end)


  #   conn = Router.call(conn("GET", "clusters/abc123/machines/123/units/test/logs", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 500
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  #   :meck.unload(CloudosBuildServer.Agents.SystemdUnit)
  # end

  # test "get unit_logs retrieve log error" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)

  #   host = Map.put(%{}, "id", "123")
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> [host] end)

  #   unit = Map.put(%{}, "name", "test")
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> [unit] end)

  #   :meck.new(CloudosBuildServer.Agents.SystemdUnit, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.SystemdUnit, :execute_journal_request, fn hosts, unit, verify_result -> {:error, "bad news bears", ""} end)


  #   conn = Router.call(conn("GET", "clusters/abc123/machines/123/units/test/logs", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 500
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  #   :meck.unload(CloudosBuildServer.Agents.SystemdUnit)
  # end

  # test "get unit_logs invalid host" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)

  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> [] end)

  #   unit = Map.put(%{}, "name", "test")
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> [unit] end)

  #   :meck.new(CloudosBuildServer.Agents.SystemdUnit, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.SystemdUnit, :execute_journal_request, fn hosts, unit, verify_result -> {:error, "bad news bears", ""} end)


  #   conn = Router.call(conn("GET", "clusters/abc123/machines/123/units/test/logs", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 404
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  #   :meck.unload(CloudosBuildServer.Agents.SystemdUnit)
  # end

  # test "get unit_logs retrieve invalid unit" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)

  #   host = Map.put(%{}, "id", "123")
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> [host] end)

  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> [] end)

  #   :meck.new(CloudosBuildServer.Agents.SystemdUnit, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.SystemdUnit, :execute_journal_request, fn hosts, unit, verify_result -> {:error, "bad news bears", ""} end)


  #   conn = Router.call(conn("GET", "clusters/abc123/machines/123/units/test/logs", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 404
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  #   :meck.unload(CloudosBuildServer.Agents.SystemdUnit)
  # end

  # test "get unit_logs no hosts" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)

  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> nil end)
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> [] end)

  #   conn = Router.call(conn("GET", "clusters/abc123/machines/123/units/test/logs", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 500
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  # end

  # test "get unit_logs no units" do
  #   :meck.new(EtcdClusterQuery, [:passthrough])
  #   :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)

  #   :meck.new(CloudosBuildServer.Agents.EtcdCluster, [:passthrough])
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :create!, fn token -> {} end)

  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_hosts, fn token -> nil end)
  #   :meck.expect(CloudosBuildServer.Agents.EtcdCluster, :get_units, fn token -> nil end)

  #   conn = Router.call(conn("GET", "clusters/abc123/machines/123/units/test/logs", JSON.encode!(%{}), [headers: [{"content-type", "application/json"}]]), [])
  #   assert conn != nil
  #   assert conn.status == 500
  # after
  #   :meck.unload(EtcdClusterQuery)
  #   :meck.unload(CloudosBuildServer.Agents.EtcdCluster)
  # end

  test "get unit_logs no cluster" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/machines/123/units/test/logs")

    assert conn.status == 404
  end
end