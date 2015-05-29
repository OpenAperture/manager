defmodule DB.Models.EtcdCluster.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Models.CloudProvider

  setup _context do
    :meck.new(Repo)

    on_exit _context, fn ->
      :meck.unload
      Repo.delete_all(EtcdCluster)
    end
  end

  test "etcd_clusters hosting provider not valid" do
    :meck.expect(Repo, :get, 2, nil)
    etcd_cluster1_values = %{:etcd_token => "abc123", :hosting_provider_id => 1}
    changeset = EtcdCluster.new(etcd_cluster1_values)
    
    refute changeset.valid?
  end

  test "etcd_clusters hosting provider is valid" do
    :meck.expect(Repo, :get, 2, %CloudProvider{id: 1})
    etcd_cluster1_values = %{:etcd_token => "abc123", :hosting_provider_id => 1}
    changeset = EtcdCluster.new(etcd_cluster1_values)
    
    assert changeset.valid?
  end

  test "etcd tokens must be unique" do
    etcd_cluster1_values = %{:etcd_token => "abc123"}
    :meck.unload
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
