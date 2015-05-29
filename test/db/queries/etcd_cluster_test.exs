defmodule DB.Queries.EtcdCluster.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Queries.EtcdCluster, as: EtcdClusterQuery
  alias OpenAperture.Manager.DB.Models.CloudProvider

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(EtcdCluster)
      Repo.delete_all(CloudProvider)
    end
  end

  test "get etcd_cluster by etcd_token" do
    cluster = EtcdCluster.new(%{etcd_token: "abc123"}) |> Repo.insert

    result = EtcdClusterQuery.get_by_etcd_token("abc123")

    assert result == cluster
  end

  test "get etcd_cluster by non-existant etcd_token returns nil" do
    _cluster = EtcdCluster.new(%{etcd_token: "abc123"}) |> Repo.insert

    result = EtcdClusterQuery.get_by_etcd_token("some bad token")

    assert result == nil
  end

  test "get etcd_cluster by id" do
    cluster_model = EtcdCluster.new(%{etcd_token: "abc123"}) |> Repo.insert

    [result] = Repo.all(EtcdClusterQuery.get_by_id(Map.from_struct(cluster_model)[:id]))
    assert Map.from_struct(result)[:etcd_token] == "abc123"
  end

  test "get clusters by cloud provider" do

    cloud_provider1 = CloudProvider.new(%{id: 1, name: "a", type: "a", configuration: "{}"}) |> Repo.insert
    _cloud_provider2 = CloudProvider.new(%{id: 2, name: "b", type: "b", configuration: "{}"}) |> Repo.insert

    _cluster_model1 = EtcdCluster.new(%{etcd_token: "abc123", hosting_provider_id: 1}) |> Repo.insert
    _cluster_model2 = EtcdCluster.new(%{etcd_token: "abc124", hosting_provider_id: 1}) |> Repo.insert
    _cluster_model3 = EtcdCluster.new(%{etcd_token: "abc125", hosting_provider_id: 2}) |> Repo.insert

    results = Repo.all(EtcdClusterQuery.get_by_cloud_provider(Map.from_struct(cloud_provider1)[:id]))
    assert length(results) == 2
  end

  test "get_docker_build_clusters" do
    build_cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}", allow_docker_builds: true}) |> Repo.insert
    _non_build_cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}", allow_docker_builds: false}) |> Repo.insert
    _cluster = EtcdCluster.new(%{etcd_token: "#{UUID.uuid1()}"}) |> Repo.insert

    clusters = Repo.all(EtcdClusterQuery.get_docker_build_clusters)
    assert clusters != nil
    assert length(clusters) == 1
    cluster = List.first(clusters)
    assert cluster.id == build_cluster.id
  end  
end