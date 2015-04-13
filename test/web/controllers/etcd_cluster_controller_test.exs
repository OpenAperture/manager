defmodule OpenAperture.Manager.EtcdClusterController.Test do
  use ExUnit.Case
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  alias OpenapertureManager.Repo
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Queries.EtcdCluster, as: EtcdClusterQuery
  alias OpenAperture.Manager.Router

  alias OpenAperture.Fleet.SystemdUnit

  setup_all _context do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit _context, fn ->
      try do
        :meck.unload
      rescue _ -> IO.puts "" end
    end    
    :ok
  end

  setup do
    :meck.new OpenapertureManager.Repo
    :meck.new FleetApi.Etcd
    on_exit fn ->
              try do
                :meck.unload OpenapertureManager.Repo
                :meck.unload FleetApi.Etcd
              rescue _ -> IO.puts "" end
            end
  end

  test "index" do
    clusters = [%EtcdCluster{etcd_token: "abc123"}]
    :meck.expect(OpenapertureManager.Repo, :all, 1, clusters)
    conn = call(Router, :get, "/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 1
    cluster = List.first(body)

    assert cluster["etcd_token"] == "abc123"
  end

  test "index - only retrieve docker build clusters" do
    :meck.unload(OpenapertureManager.Repo)
    Repo.delete_all(EtcdCluster)

    build_cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}", allow_docker_builds: true}) |> Repo.insert
    non_build_cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}", allow_docker_builds: false}) |> Repo.insert
    cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}"}) |> Repo.insert

    conn = call(Router, :get, "/clusters?allow_docker_builds=true")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 1
    cluster = List.first(body)
    assert cluster["etcd_token"] == build_cluster.etcd_token
  after
    :meck.new OpenapertureManager.Repo
  end

  test "index returns empty list if no clusters" do
    :meck.expect(OpenapertureManager.Repo, :all, 1, [])
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
    conn = call(Router, :post, "/clusters", Poison.encode!(%{}), [{"content-type", "application/json"}])

    assert conn.status == 400

    body = Poison.decode!(conn.resp_body)

    assert body == %{"etcd_token" => "required"}
  end

  test "register action -- success" do
    cluster = %EtcdCluster{id: 1, etcd_token: "token"}
    :meck.expect(Repo, :insert, 1, cluster)
    conn = call(Router, :post, "/clusters", Poison.encode!(cluster), [{"content-type", "application/json"}])

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
  test "get machines success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, []})

    conn = call(Router, :get, "/clusters/some_etcd_token/machines")

    assert conn.status == 200
  end

  test "get machines not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/machines")

    assert conn.status == 404
  end

  test "get machines fail" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, nil})

    conn = call(Router, :get, "/clusters/some_etcd_token/machines")
    assert conn.status == 500
  end

  # #=========
  # # tests for units
  test "get units success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})

    conn = call(Router, :get, "/clusters/some_etcd_token/units")
    assert conn.status == 200
  end

  test "get units not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/units")

    assert conn.status == 404
  end

  test "get units fail" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, nil})

    conn = call(Router, :get, "/clusters/some_etcd_token/units")
    assert conn.status == 500
  end

  # #=========
  # # tests for units_state
  test "get units_state success" do
     :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
     :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
     :meck.expect(FleetApi.Etcd, :list_unit_states, 1, {:ok, []})

     conn = call(Router, :get, "/clusters/some_etcd_token/state")
     assert conn.status == 200
  end

  test "get units_state not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/state")

    assert conn.status == 404
  end

  test "get units_state fail" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_unit_states, 1, {:ok, nil})

    conn = call(Router, :get, "/clusters/some_etcd_token/state")
    assert conn.status == 500
  end

  # #=========
  # # tests for unit_logs
  test "get unit_logs success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, [%FleetApi.Machine{id: "123"}]})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, [%FleetApi.Unit{name: "test"}]})
    :meck.expect(SystemdUnit, :execute_journal_request, 3, {:ok, "happy result", ""})

    conn = call(Router, :get, "/clusters/some_etcd_token/machines/123/units/test/logs")
    assert conn.status == 200
  end

  test "get unit_logs retrieve log error" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, [%FleetApi.Machine{id: "123"}]})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, [%FleetApi.Unit{name: "test"}]})
    :meck.expect(SystemdUnit, :execute_journal_request, 3, {:error, "bad news bears", ""})

    conn = call(Router, :get, "/clusters/some_etcd_token/machines/123/units/test/logs")
    assert conn.status == 500
  end

  test "get unit_logs invalid host" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, []})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, [%FleetApi.Unit{name: "test"}]})

    conn = call(Router, :get, "/clusters/some_etcd_token/machines/123/units/test/logs")
    assert conn.status == 404
  end

  test "get unit_logs retrieve invalid unit" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, [%FleetApi.Machine{id: "123"}]})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, []})

    conn = call(Router, :get, "/clusters/some_etcd_token/machines/123/units/test/logs")
    assert conn.status == 404
  end

  test "get unit_logs no hosts" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, nil})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, [%FleetApi.Unit{name: "test"}]})

    conn = call(Router, :get, "/clusters/some_etcd_token/machines/123/units/test/logs")
    assert conn.status == 500
  end

  test "get unit_logs no units" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetApi.Etcd, :start_link, 1, {:ok, :some_pid})
    :meck.expect(FleetApi.Etcd, :list_machines, 1, {:ok, [%FleetApi.Machine{id: "123"}]})
    :meck.expect(FleetApi.Etcd, :list_units, 1, {:ok, nil})

    conn = call(Router, :get, "/clusters/some_etcd_token/machines/123/units/test/logs")
    assert conn.status == 500
  end

  test "get unit_logs no cluster" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = call(Router, :get, "/clusters/some_etcd_token/machines/123/units/test/logs")

    assert conn.status == 404
  end
end