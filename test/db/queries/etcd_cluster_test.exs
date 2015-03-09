defmodule DB.Queries.EtcdCluster.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Queries.EtcdCluster, as: EtcdClusterQuery

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(EtcdCluster)
    end
  end

  test "get etcd_cluster by etcd_token" do
    cluster = %EtcdCluster{etcd_token: "abc123"}
    cluster = Repo.insert(cluster)

    result = EtcdClusterQuery.get_by_etcd_token("abc123")

    assert result == cluster
  end

  test "get etcd_cluster by non-existant etcd_token returns nil" do
    cluster = %EtcdCluster{etcd_token: "abc123"}
    Repo.insert(cluster)

    result = EtcdClusterQuery.get_by_etcd_token("some bad token")

    assert result == nil
  end

  test "get etcd_cluster by id" do
    cluster = %EtcdCluster{etcd_token: "abc123"}
    cluster_model = Repo.insert(cluster)

    [result] = Repo.all(EtcdClusterQuery.get_by_id(Map.from_struct(cluster_model)[:id]))
    assert Map.from_struct(result)[:etcd_token] == "abc123"
  end  
end