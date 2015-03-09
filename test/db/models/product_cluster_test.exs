defmodule DB.Models.ProductCluster.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Models.ProductCluster

  setup _context do
    product = Repo.insert(%Product{name: "test product"})
    etcd_cluster = Repo.insert(%EtcdCluster{etcd_token: "abc123"})

    product2 = Repo.insert(%Product{name: "test product2"})
    etcd_cluster2 = Repo.insert(%EtcdCluster{etcd_token: "bcd234"})
    etcd_cluster3 = Repo.insert(%EtcdCluster{etcd_token: "zyx987"})

    on_exit _context, fn ->
      Repo.delete_all(ProductCluster)
      Repo.delete_all(Product)
      Repo.delete_all(EtcdCluster)
    end

    {:ok, [product: product, product2: product2, cluster: etcd_cluster, etcd_cluster2: etcd_cluster2, etcd_cluster3: etcd_cluster3]}
  end

  test "validate - fail to create cluster with missing values" do
    product_cluster = %ProductCluster{}
    result          = ProductCluster.validate(product_cluster)

    assert map_size(result)         != 0
    assert result[:product_id]      != nil
    assert result[:etcd_cluster_id] != nil
  end

  test "validate - success", context do
    product_cluster = %ProductCluster{product_id: context[:product].id, etcd_cluster_id: context[:cluster].id}
    result = ProductCluster.validate(product_cluster)

    assert is_nil(result)
  end

  test "single cluster", context do
    product_cluster = %ProductCluster{product_id: context[:product].id, etcd_cluster_id: context[:cluster].id}

    new_cluster = Repo.insert(product_cluster)

    retrieved_cluster = Repo.get(ProductCluster, new_cluster.id)

    assert retrieved_cluster == new_cluster
    assert retrieved_cluster.product_id == context[:product].id
    assert retrieved_cluster.etcd_cluster_id == context[:cluster].id
  end

  test "multiple clusters", context do
    product_cluster = Repo.insert(%ProductCluster{product_id: context[:product2].id, etcd_cluster_id: context[:etcd_cluster2].id})
    product_cluster1 = Repo.insert(%ProductCluster{product_id: context[:product2].id, etcd_cluster_id: context[:etcd_cluster3].id})

    retrieved_cluster = Repo.get(ProductCluster, product_cluster.id)
    assert retrieved_cluster == product_cluster
    assert retrieved_cluster.product_id == context[:product2].id
    assert retrieved_cluster.etcd_cluster_id == context[:etcd_cluster2].id

    retrieved_cluster = Repo.get(ProductCluster, product_cluster1.id)
    assert retrieved_cluster == product_cluster1
    assert retrieved_cluster.product_id == context[:product2].id
    assert retrieved_cluster.etcd_cluster_id == context[:etcd_cluster3].id
  end
end
