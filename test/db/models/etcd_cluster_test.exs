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
    etcd_cluster1 = EtcdCluster.new(%{:etcd_token => "abc123"})
    Repo.insert(etcd_cluster1)

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"etcd_clusters_etcd_token_index\"",
                 fn -> Repo.insert(etcd_cluster1) end
  end

  test "etcd_clusters etcd_token is required" do
    etcd_cluster = EtcdCluster.new(%{:id => 1})
    result = EtcdCluster.changeset(etcd_cluster)

    assert !result.valid?
    assert [etcd_token: :required] = result.model.errors
  end
end
