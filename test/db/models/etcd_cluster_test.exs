defmodule DB.Models.EtcdCluster.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.EtcdCluster

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(EtcdCluster)
    end
  end

  test "etcd tokens must be unique" do
    etcd_cluster1 = %EtcdCluster{:etcd_token => "abc123"}
    EtcdCluster.vinsert(etcd_cluster1)

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"etcd_clusters_etcd_token_index\"",
                 fn -> EtcdCluster.vinsert(etcd_cluster1) end
  end

  test "etcd_clusters etcd_token is required" do
    {status, errors} = EtcdCluster.vinsert(%EtcdCluster{:id => 1})
    assert status == :error
    assert Keyword.has_key?(errors, :etcd_token)
  end
end
