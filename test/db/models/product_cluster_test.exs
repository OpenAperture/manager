defmodule DB.Models.ProductCluster.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Models.ProductCluster

  setup _context do
    {:ok, product} = Product.vinsert(%{name: "test product"})
    {:ok, etcd_cluster} = EtcdCluster.vinsert(%EtcdCluster{etcd_token: "abc123"})

    {:ok, product2} = Product.vinsert(%{name: "test product2"})
    {:ok, etcd_cluster2} = EtcdCluster.vinsert(%{etcd_token: "bcd234"})
    {:ok, etcd_cluster3} = EtcdCluster.vinsert(%{etcd_token: "zyx987"})

    on_exit _context, fn ->
      Repo.delete_all(ProductCluster)
      Repo.delete_all(Product)
      Repo.delete_all(EtcdCluster)
    end

    {:ok, [product: product, product2: product2, cluster: etcd_cluster, etcd_cluster2: etcd_cluster2, etcd_cluster3: etcd_cluster3]}
  end

  test "validate - fail to create cluster with missing values" do
    {status, errors} = ProductCluster.vinsert(%{})
    assert status == :error
    assert Keyword.has_key?(errors, :product_id)
    assert Keyword.has_key?(errors, :etcd_cluster_id)
  end

  test "validate - success", context do
    {status, _result} = ProductCluster.vinsert(%{product_id: context[:product].id, etcd_cluster_id: context[:cluster].id})
    assert status == :ok
  end

  test "single cluster", context do
    product_cluster = %{product_id: context[:product].id, etcd_cluster_id: context[:cluster].id}

    {:ok, new_cluster} = ProductCluster.vinsert(product_cluster)

    retrieved_cluster = Repo.get(ProductCluster, new_cluster.id)

    assert retrieved_cluster == new_cluster
    assert retrieved_cluster.product_id == context[:product].id
    assert retrieved_cluster.etcd_cluster_id == context[:cluster].id
  end

  test "multiple clusters", context do
    {:ok, product_cluster} = ProductCluster.vinsert(%{product_id: context[:product2].id, etcd_cluster_id: context[:etcd_cluster2].id})
    {:ok, product_cluster1} = ProductCluster.vinsert(%{product_id: context[:product2].id, etcd_cluster_id: context[:etcd_cluster3].id})

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
