defmodule DB.Models.EtcdCluster.Test do
  use ExUnit.Case, async: false

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.EtcdCluster

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(EtcdCluster)
    end
  end

  test "etcd tokens must be unique" do
    etcd_cluster1_values = %{:etcd_token => "abc123"}
    EtcdCluster.new(etcd_cluster1_values) |> Repo.insert

    assert_raise Postgrex.Error,
                 "ERROR (unique_violation): duplicate key value violates unique constraint \"etcd_clusters_etcd_token_index\"",
                 fn -> EtcdCluster.new(etcd_cluster1_values) |> Repo.insert end
  end

  test "etcd_clusters etcd_token is required" do
    changeset = EtcdCluster.new(%{:id => 1})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :etcd_token)
  end
end
