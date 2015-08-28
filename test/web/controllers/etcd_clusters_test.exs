defmodule OpenAperture.Manager.Controllers.EtcdClustersTest do
  use ExUnit.Case, async: false
  use Phoenix.ConnTest

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Queries.EtcdCluster, as: EtcdClusterQuery
  alias OpenAperture.Manager.DB.Models.CloudProvider

  alias OpenAperture.Manager.Messaging.FleetManagerPublisher
  alias OpenAperture.Messaging.AMQP.RpcHandler

  setup do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :authenticate_user, fn conn, _opts -> conn end)
    :meck.new OpenAperture.Manager.Repo
    :meck.new FleetManagerPublisher
    :meck.new RpcHandler
    on_exit fn ->
      :meck.unload
    end
    :ok
  end

  @endpoint OpenAperture.Manager.Endpoint

  test "index" do
    clusters = [%EtcdCluster{etcd_token: "abc123"}]
    :meck.expect(OpenAperture.Manager.Repo, :all, 1, clusters)
    conn = get conn(), "/clusters"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 1
    cluster = List.first(body)

    assert cluster["etcd_token"] == "abc123"
  end

  test "index - only retrieve docker build clusters" do
    :meck.unload(OpenAperture.Manager.Repo)
    Repo.delete_all(EtcdCluster)

    build_cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}", allow_docker_builds: true}) |> Repo.insert!
    non_build_cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}", allow_docker_builds: false}) |> Repo.insert!
    cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}"}) |> Repo.insert!

    conn = get conn(), "/clusters?allow_docker_builds=true"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 1
    cluster = List.first(body)
    assert cluster["etcd_token"] == build_cluster.etcd_token
  after
    :meck.new OpenAperture.Manager.Repo
  end

  test "index returns empty list if no clusters" do
    :meck.expect(OpenAperture.Manager.Repo, :all, 1, [])
    conn = get conn(), "/clusters"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "show returns 404 if a matching cluster wasn't found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = get conn(), "/clusters/some_etcd_token"

    assert conn.status == 404
  end

  test "show returns the matched etcd cluster" do
    cluster = %EtcdCluster{etcd_token: "abc123"}
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, cluster)

    conn = get conn(), "/clusters/some_etcd_token"

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)

    assert body["etcd_token"] == "abc123"
  end

  test "register action - bad request if no etcd_token is provided" do
    conn = post conn(), "/clusters", %{}

    assert conn.status == 400

    body = Poison.decode!(conn.resp_body)

    assert body ==  %{"errors" => [%{"message" => "One or more fields for EtcdCluster were invalid"}, %{"etcd_token" => "can't be blank"}]}
  end

  test "register action -- success" do
    cluster = %EtcdCluster{id: 1, etcd_token: "token"}
    :meck.expect(Repo, :insert!, 1, cluster)
    conn = post conn(), "/clusters", Map.from_struct(cluster)

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)
    location_header = List.keyfind(conn.resp_headers, "location", 0)

    assert location_header == {"location", "/clusters/token"}
  end

  test "register action -- provided invalid hosting_provider_id" do
    cluster = %EtcdCluster{id: 1, etcd_token: "token", hosting_provider_id: 1}
    :meck.expect(Repo, :get, 2, nil)
    :meck.expect(Repo, :insert!, 1, cluster)
    conn = post conn(), "/clusters", Map.from_struct(cluster)

    assert conn.status == 400

    body = Poison.decode!(conn.resp_body)
    assert body["errors"] |> List.last |> Map.has_key?("hosting_provider_id")
  end

  test "register action -- provided valid hosting_provider_id" do
    cluster = %EtcdCluster{id: 1, etcd_token: "token", hosting_provider_id: 1}
    :meck.expect(Repo, :get, 2, %CloudProvider{id: 1})
    :meck.expect(Repo, :insert!, 1, cluster)
    conn = post conn(), "/clusters", Map.from_struct(cluster)

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)
    location_header = List.keyfind(conn.resp_headers, "location", 0)

    assert location_header == {"location", "/clusters/token"}
  end

  test "destroy action -- not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = delete conn(), "/clusters/some_etcd_token"

    assert conn.status == 404
  end

  test "destroy action -- success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, %EtcdCluster{id: 1, etcd_token: "some_etcd_token"})
    :meck.expect(Repo, :delete!, 1, 1)

    conn = delete conn(), "/clusters/some_etcd_token"

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

    conn = get conn(), "/clusters/#{cluster.etcd_token}/products"

    assert conn.status == 200

    resp_products = Poison.decode!(conn.resp_body)
    assert length(resp_products) == 2

  end

  test "no associated products" do
    cluster = %EtcdCluster{etcd_token: "#{UUID.uuid1()}"}
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, cluster)
    :meck.expect(Repo, :all, 1, [])

    conn = get conn(), "/clusters/#{cluster.etcd_token}/products"

    assert conn.status == 200

    resp_products = Poison.decode!(conn.resp_body)
    assert length(resp_products) == 0
  end

  test "associated products to invalid etcd token results in 404" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = get conn(), "/clusters/some_etcd_token/products"

    assert conn.status == 404
  end

  #=========
  # tests for machines

  test "get machines success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_machines!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, []} end)

    conn = get conn(), "/clusters/some_etcd_token/machines"

    assert conn.status == 200
  end

  test "get machines not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = get conn(), "/clusters/some_etcd_token/machines"

    assert conn.status == 404
  end

  test "get machines fail" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_machines!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:error, "bad news bears"} end)

    conn = get conn(), "/clusters/some_etcd_token/machines"
    assert conn.status == 500
  end

  test "get machines invalid" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_machines!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, nil} end)

    conn = get conn(), "/clusters/some_etcd_token/machines"
    assert conn.status == 500
  end

  #=========
  # tests for units

  test "get units success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_units!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, []} end)

    conn = get conn(), "/clusters/some_etcd_token/units"
    assert conn.status == 200
  end

  test "get units not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = get conn(), "/clusters/some_etcd_token/units"

    assert conn.status == 404
  end

  test "get units fail" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_units!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:error, "bad news bears"} end)

    conn = get conn(), "/clusters/some_etcd_token/units"
    assert conn.status == 500
  end

  test "get units invalid" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_units!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, nil} end)

    conn = get conn(), "/clusters/some_etcd_token/units"
    assert conn.status == 500
  end

  #=========
  # tests for units_state

  test "get units_state success" do
     :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_unit_states!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, []} end)

     conn = get conn(), "/clusters/some_etcd_token/state"
     assert conn.status == 200
  end

  test "get units_state not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = get conn(), "/clusters/some_etcd_token/state"

    assert conn.status == 404
  end

  test "get units_state fail" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_unit_states!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:error, "bad news bears"} end)

    conn = get conn(), "/clusters/some_etcd_token/state"
    assert conn.status == 500
  end

  test "get units_state invalid" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_unit_states!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, nil} end)

    conn = get conn(), "/clusters/some_etcd_token/state"
    assert conn.status == 500
  end

  #=========
  # tests for unit_logs

  test "get unit_logs success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :unit_logs!, fn _,_,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, ""} end)

    conn = get conn(), "/clusters/some_etcd_token/machines/123/units/test/logs"
    assert conn.status == 200
  end

  test "get unit_logs retrieve log error" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :unit_logs!, fn _,_,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:error, "bad news bears"} end)

    conn = get conn(), "/clusters/some_etcd_token/machines/123/units/test/logs"
    assert conn.status == 500
  end

  test "get unit_logs invalid" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :unit_logs!, fn _,_,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, nil} end)

    conn = get conn(), "/clusters/some_etcd_token/machines/123/units/test/logs"
    assert conn.status == 500
  end

  test "get unit_logs no cluster" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = get conn(), "/clusters/some_etcd_token/machines/123/units/test/logs"

    assert conn.status == 404
  end

  #=========
  # node_info tests

  test "node_info machines not found" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = get conn(), "/clusters/some_etcd_token/nodes"

    assert conn.status == 404
  end

  test "node_info machines fail" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_machines!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:error, "bad news bears"} end)

    conn = get conn(), "/clusters/some_etcd_token/nodes"
    assert conn.status == 500
  end

  test "node_info machines invalid" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_machines!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, nil} end)

    conn = get conn(), "/clusters/some_etcd_token/nodes"
    assert conn.status == 500
  end  

  test "node_info no machines" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_machines!, fn _,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, []} end)

    conn = get conn(), "/clusters/some_etcd_token/nodes"

    assert conn.status == 200
  end

  test "node_info machines" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :list_machines!, fn _,_ -> "machines_handler" end)
    :meck.expect(FleetManagerPublisher, :node_info!, fn _,_ -> "info_handler" end)
    :meck.expect(RpcHandler, :get_response, fn handler_type -> 
      cond do
        handler_type == "machines_handler" -> {:ok, [%{"primaryIP" => "123.234.456.789"}]} 
        handler_type == "info_handler" -> {:ok, %{"123.234.456.789" => %{}}}
        true -> nil
      end
    end)

    conn = get conn(), "/clusters/some_etcd_token/nodes"

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert body != nil
    assert body["123.234.456.789"] != nil
  end
 
  #=========
  # tests for restart_unit

  test "get restart_unit success" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :restart_unit!, fn _,_,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, ""} end)

    conn = get conn(), "/clusters/some_etcd_token/machines/123/units/test/restart"
    assert conn.status == 200
  end

  test "get restart_unit retrieve log error" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :restart_unit!, fn _,_,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:error, "bad news bears"} end)

    conn = get conn(), "/clusters/some_etcd_token/machines/123/units/test/restart"
    assert conn.status == 500
  end

  test "get restart_unit invalid" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, fn token -> %EtcdCluster{etcd_token: token} end)
    :meck.expect(FleetManagerPublisher, :restart_unit!, fn _,_,_ -> %{} end)
    :meck.expect(RpcHandler, :get_response, fn _ -> {:ok, nil} end)

    conn = get conn(), "/clusters/some_etcd_token/machines/123/units/test/restart"
    assert conn.status == 500
  end

  test "get restart_unit no cluster" do
    :meck.expect(EtcdClusterQuery, :get_by_etcd_token, 1, nil)

    conn = get conn(), "/clusters/some_etcd_token/machines/123/units/test/restart"

    assert conn.status == 404
  end 
end