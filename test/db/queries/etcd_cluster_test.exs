defmodule DB.Queries.EtcdCluster.Test do
  use ExUnit.Case, async: false

  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Queries.EtcdCluster, as: EtcdClusterQuery

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(EtcdCluster)
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