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
    :meck.new Repo

    on_exit _context, fn ->
      try do
        :meck.unload(Repo)
      rescue _ -> 
        Repo.delete_all(EtcdCluster)
        Repo.delete_all(CloudProvider)
      end

      try do
        :meck.unload(OpenAperture.Manager.Plugs.Authentication)
        :meck.unload
      rescue _ -> IO.puts "" end
    end    
    :ok
  end

  test "index action" do
    providers = [%CloudProvider{id: 1, name: "aws", type: "aws", configuration: "{}"}, %CloudProvider{id: 2, name: "azure", type: "azure", configuration: "{}"}]
    :meck.expect(Repo, :all, 1, providers)

    conn = call(Router, :get, "/cloud_providers")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2

    assert Enum.any?(body, &(&1["id"] == 1))
    assert Enum.any?(body, &(&1["id"] == 2))
    assert Enum.any?(body, &(&1["name"] == "aws"))
    assert Enum.any?(body, &(&1["name"] == "azure"))
    assert Enum.any?(body, &(&1["type"] == "aws"))
    assert Enum.any?(body, &(&1["type"] == "azure"))
    assert Enum.any?(body, &(&1["configuration"] == "{}"))
    assert Enum.any?(body, &(&1["configuration"] == "{}"))
  end

  test "show action - found" do
    provider = %CloudProvider{id: 1, name: "aws", type: "aws", configuration: "{}"}
    :meck.expect(Repo, :get, 2, provider)

    conn = call(Router, :get, "/cloud_providers/1")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["id"] == 1
  end

  test "show action -- not found" do
    :meck.expect(Repo, :get, 2, nil)

    conn = call(Router, :get, "/cloud_providers/1")

    assert conn.status == 404
  end

  test "create action -- success" do
    provider = %CloudProvider{id: 1, name: "aws", type: "aws", configuration: "{}"}
    :meck.expect(Repo, :insert, 1, provider)

    conn = call(Router, :post, "/cloud_providers", Poison.encode!(%{name: "aws", type: "aws", configuration: "{}"}), [{"content-type", "application/json"}])

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/cloud_providers/1" == location
  end

  test "create action -- bad request on invalid values" do
    :meck.expect(Repo, :one, 1, nil)

    conn = call(Router, :post, "/cloud_providers", Poison.encode!(%{name: "", type: "", configuration: ""}), [{"content-type", "application/json"}])
    
    assert conn.status == 400

    assert String.contains?(conn.resp_body, "name")
    assert String.contains?(conn.resp_body, "type")
    assert String.contains?(conn.resp_body, "configuration") 
  end

  test "delete action -- success" do
    provider = %CloudProvider{id: 1, name: "aws", type: "aws", configuration: "{}"}
    :meck.expect(Repo, :get, 2, provider)
    :meck.expect(Repo, :delete, 1, provider)

    conn = call(Router, :delete, "/cloud_providers/1")

    assert conn.status == 204
  end

  test "delete action -- not found" do
    :meck.expect(Repo, :get, 2, nil)

    conn = call(Router, :delete, "/cloud_providers/1")

    assert conn.status == 404
  end

  test "update action -- success" do
    provider = %CloudProvider{id: 1, name: "aws", type: "aws", configuration: "{}"}
    updated_provider = %CloudProvider{id: 1, name: "azure", type: "azure", configuration: "{some_config}"}
    :meck.expect(Repo, :get, 2, provider)

    :meck.expect(Repo, :update, 1, updated_provider)

    conn = call(Router, :put, "/cloud_providers/1", Poison.encode!(%{name: "azure", type: "azure", configuration: "{some_config}"}), [{"content-type", "application/json"}])

    assert conn.status == 204

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert "/cloud_providers/1" == location
  end

  test "update action -- not found" do
    :meck.expect(Repo, :get, 2, nil)

    conn = call(Router, :put, "/cloud_providers/1", Poison.encode!(%{name: "azure", type: "azure", configuration: "{some_config}"}), [{"content-type", "application/json"}])

    assert conn.status == 404
  end

  test "update action -- fails on invalid change" do
    provider = %CloudProvider{id: 1, name: "aws", type: "aws", configuration: "{}"}
    :meck.expect(Repo, :get, 2, provider)

    conn = call(Router, :put, "/cloud_providers/1", Poison.encode!(%{name: "", type: "", configuration: ""}), [{"content-type", "application/json"}])

    assert conn.status == 400

    assert String.contains?(conn.resp_body, "name")
    assert String.contains?(conn.resp_body, "type")
    assert String.contains?(conn.resp_body, "configuration") 
  end

  test "clusters action -- provider found" do 
    :meck.unload(Repo)
    provider = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider.id}) |> Repo.insert
    cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider.id}) |> Repo.insert

    conn = call(Router, :get, "/cloud_providers/#{provider.id}/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2
  end

  test "clusters action -- provider has no clusters" do
    :meck.unload(Repo)
    provider1 = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    provider2 = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider2.id}) |> Repo.insert
    cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider2.id}) |> Repo.insert

    conn = call(Router, :get, "/cloud_providers/#{provider1.id}/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "clusters action -- provider does not exist" do
    :meck.unload(Repo)
    provider = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider.id}) |> Repo.insert
    cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider.id}) |> Repo.insert

    conn = call(Router, :get, "/cloud_providers/-1/clusters")

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

end