defmodule OpenAperture.Manager.Controllers.CloudProvidersTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  alias OpenAperture.Manager.DB.Models.CloudProvider
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.Repo

  @endpoint OpenAperture.Manager.Endpoint

  setup context do
    :meck.new(OpenAperture.Manager.Plugs.Authentication, [:passthrough])
    :meck.expect(OpenAperture.Manager.Plugs.Authentication, :call, fn conn, _opts -> conn end)

    on_exit context, fn ->
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

    conn = get conn(), "/cloud_providers"

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

    conn = get conn, "/cloud_providers/#{provider.id}"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert body["id"] == provider.id
  end

  test "show action -- not found" do
    conn = get conn(), "/cloud_providers/1"


    assert conn.status == 404
  end

  test "create action -- success" do
    conn = post conn(), "/cloud_providers", [name: "aws", type: "aws", configuration: "{}"]

    assert conn.status == 201

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert Regex.match?(~r/\/cloud_providers\/\d+/, location)
  end

  test "create action -- bad request on invalid values" do
    conn = post conn(), "/cloud_providers", [name: "", type: "", configuration: ""]
    assert conn.status == 400

    assert String.contains?(conn.resp_body, "name")
    assert String.contains?(conn.resp_body, "type")
    assert String.contains?(conn.resp_body, "configuration") 
  end

  test "delete action -- success" do
    provider = CloudProvider.new(%{name: "aws", type: "aws", configuration: "{}"}) |> Repo.insert

    conn = delete conn(), "/cloud_providers/#{provider.id}"

    assert conn.status == 204
  end

  test "delete action -- not found" do
    conn = delete conn(), "/cloud_providers/1"

    assert conn.status == 404
  end

  test "update action -- success" do
    provider = CloudProvider.new(%{name: "aws", type: "aws", configuration: "{}"}) |> Repo.insert

    conn = put conn(), "/cloud_providers/#{provider.id}", [name: "azure", type: "azure", configuration: "{some_config}"]
    
    assert conn.status == 204

    assert List.keymember?(conn.resp_headers, "location", 0)

    {_, location} = List.keyfind(conn.resp_headers, "location", 0)

    assert Regex.match?(~r/\/cloud_providers\/\d+/, location)
  end

  test "update action -- not found" do
    conn = put conn(), "/cloud_providers/1", name: "azure", type: "azure", configuration: "{some_config}"
    assert conn.status == 404
  end

  test "update action -- fails on invalid change" do
    provider = CloudProvider.new(%{name: "aws", type: "aws", configuration: "{}"}) |> Repo.insert

    conn = put conn(), "/cloud_providers/#{provider.id}", [name: "", type: "", configuration: ""]
    assert conn.status == 400

    assert String.contains?(conn.resp_body, "name")
    assert String.contains?(conn.resp_body, "type")
    assert String.contains?(conn.resp_body, "configuration") 
  end

  test "clusters action -- provider found" do 
    provider = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    _cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider.id}) |> Repo.insert
    _cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider.id}) |> Repo.insert

    conn = get conn(), "/cloud_providers/#{provider.id}/clusters"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 2
  end

  test "clusters action -- provider has no clusters" do
    provider1 = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    provider2 = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    _cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider2.id}) |> Repo.insert
    _cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider2.id}) |> Repo.insert

    conn = get conn(), "/cloud_providers/#{provider1.id}/clusters"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end

  test "clusters action -- provider does not exist" do
    provider = CloudProvider.new(%{name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    _cluster1 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: provider.id}) |> Repo.insert
    _cluster2 = EtcdCluster.new(%{etcd_token: "abc126", hosting_provider_id: provider.id}) |> Repo.insert
    
    conn = get conn(), "/cloud_providers/-1/clusters"

    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)

    assert length(body) == 0
  end
end