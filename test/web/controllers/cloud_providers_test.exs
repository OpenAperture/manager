defmodule OpenAperture.Manager.Controllers.CloudProvidersTest do
  use ExUnit.Case
  use Plug.Test
  use OpenAperture.Manager.Test.ConnHelper

  alias OpenAperture.Manager.DB.Models.CloudProvider
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.Router
  alias OpenAperture.Manager.Repo

  setup _context do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit _context, fn ->
      try do
        :meck.unload
      rescue _ -> IO.puts "" end
      Repo.delete_all(EtcdCluster)
      Repo.delete_all(CloudProvider)
    end    
    :ok
  end

  test "index action" do
    provider1 = CloudProvider.new(%{id: 1, name: "aws", type: "aws", configuration: "{}"}) |> Repo.insert
    provider2 = CloudProvider.new(%{id: 2, name: "azure", type: "azure", configuration: "{}"}) |> Repo.insert

    conn = call(Router, :get, "/cloud_providers")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2

    assert Enum.any?(body, &(&1["id"] == provider1.id))
    assert Enum.any?(body, &(&1["id"] == provider2.id))
    assert Enum.any?(body, &(&1["name"] == "aws"))
    assert Enum.any?(body, &(&1["name"] == "azure"))
    assert Enum.any?(body, &(&1["type"] == "aws"))
    assert Enum.any?(body, &(&1["type"] == "azure"))
    assert Enum.any?(body, &(&1["configuration"] == "{}"))
    assert Enum.any?(body, &(&1["configuration"] == "{}"))
  end

  test "show action - found" do
    provider = CloudProvider.new(%{name: "aws", type: "aws", configuration: "{}"}) |> Repo.insert

    conn = call(Router, :get, "/cloud_providers/#{provider.id}")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["id"] == provider.id
  end

  test "show action -- not found" do
    conn = call(Router, :get, "/cloud_providers/1")

    assert conn.status == 404
  end

  test "create action -- success" do
    conn = call(Router, :post, "/cloud_providers", Poison.encode!(%{name: "aws", type: "aws", configuration: "{}"}), [{"content-type", "application/json"}])

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert Regex.match?(~r/\/cloud_providers\/\d+/, location)
  end

  test "create action -- bad request on invalid values" do
    conn = call(Router, :post, "/cloud_providers", Poison.encode!(%{name: "", type: "", configuration: ""}), [{"content-type", "application/json"}])
    
    assert conn.status == 400

    IO.inspect(conn.resp_body)

    assert String.contains?(conn.resp_body, "name")
    assert String.contains?(conn.resp_body, "type")
    assert String.contains?(conn.resp_body, "configuration") 
  end

  test "delete action -- success" do
    provider = CloudProvider.new(%{name: "aws", type: "aws", configuration: "{}"}) |> Repo.insert

    conn = call(Router, :delete, "/cloud_providers/#{provider.id}")

    assert conn.status == 204
  end

  test "delete action -- not found" do
    conn = call(Router, :delete, "/cloud_providers/1")

    assert conn.status == 404
  end

  test "update action -- success" do
    provider = CloudProvider.new(%{name: "aws", type: "aws", configuration: "{}"}) |> Repo.insert

    conn = call(Router, :put, "/cloud_providers/#{provider.id}", Poison.encode!(%{name: "azure", type: "azure", configuration: "{some_config}"}), [{"content-type", "application/json"}])

    assert conn.status == 204

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert Regex.match?(~r/\/cloud_providers\/\d+/, location)
  end

  test "update action -- not found" do
    conn = call(Router, :put, "/cloud_providers/1", Poison.encode!(%{name: "azure", type: "azure", configuration: "{some_config}"}), [{"content-type", "application/json"}])

    assert conn.status == 404
  end

  test "update action -- fails on invalid change" do
    provider = CloudProvider.new(%{name: "aws", type: "aws", configuration: "{}"}) |> Repo.insert

    conn = call(Router, :put, "/cloud_providers/#{provider.id}", Poison.encode!(%{name: "", type: "", configuration: ""}), [{"content-type", "application/json"}])

    assert conn.status == 400

    assert String.contains?(conn.resp_body, "name")
    assert String.contains?(conn.resp_body, "type")
    assert String.contains?(conn.resp_body, "configuration") 
  end

  test "clusters action -- provider found" do 
    provider = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    _cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider.id}) |> Repo.insert
    _cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider.id}) |> Repo.insert

    conn = call(Router, :get, "/cloud_providers/#{provider.id}/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2
  end

  test "clusters action -- provider has no clusters" do
    provider1 = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    provider2 = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    _cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider2.id}) |> Repo.insert
    _cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider2.id}) |> Repo.insert

    conn = call(Router, :get, "/cloud_providers/#{provider1.id}/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "clusters action -- provider does not exist" do
    provider = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    _cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider.id}) |> Repo.insert
    _cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider.id}) |> Repo.insert

    conn = call(Router, :get, "/cloud_providers/-1/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end
end