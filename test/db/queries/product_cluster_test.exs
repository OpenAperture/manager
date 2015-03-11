defmodule DB.Queries.ProductCluster.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Models.ProductCluster
  alias ProjectOmeletteManager.DB.Queries.ProductCluster, as: PCQuery

  setup_all _context do
    {:ok, product} = Product.vinsert(%{name: "test product"})
    {:ok, etcd_cluster} = EtcdCluster.vinsert(%{etcd_token: "abc123"})
    {:ok, _product_cluster} = ProductCluster.vinsert(%{product_id: product.id, etcd_cluster_id: etcd_cluster.id})

    {:ok, product2} = Product.vinsert(%{name: "test product2"})
    {:ok, etcd_cluster2} = EtcdCluster.vinsert(%{etcd_token: "bcd234"})
    {:ok, etcd_cluster3} = EtcdCluster.vinsert(%{etcd_token: "zyx987"})
    {:ok, _product_cluster2} = ProductCluster.vinsert(%{product_id: product2.id, etcd_cluster_id: etcd_cluster2.id})
    {:ok, _product_cluster2} = ProductCluster.vinsert(%{product_id: product2.id, etcd_cluster_id: etcd_cluster3.id})

    {:ok, product3} = Product.vinsert(%{name: "test product3"})
    {:ok, product4} = Product.vinsert(%{name: "test product4"})
    {:ok, etcd_cluster4} = EtcdCluster.vinsert(%{etcd_token: "#{UUID.uuid1()}"})
    {:ok, _product_cluster3} = ProductCluster.vinsert(%{product_id: product3.id, etcd_cluster_id: etcd_cluster4.id})
    {:ok, _product_cluster4} = ProductCluster.vinsert(%{product_id: product4.id, etcd_cluster_id: etcd_cluster4.id})

    on_exit _context, fn ->
      Repo.delete_all(ProductCluster)
      Repo.delete_all(Product)
      Repo.delete_all(EtcdCluster)
    end

    {:ok, [product: product, product2: product2, cluster: etcd_cluster, etcd_cluster2: etcd_cluster2, etcd_cluster3: etcd_cluster3, etcd_cluster4: etcd_cluster4]}
  end

  test "find etcd cluster by product id", context do
    results = Repo.all(PCQuery.get_etcd_clusters(context[:product].id))
    assert length(results) == 1
  end

  test "find etcd clusters by product id", context do
    results = Repo.all(PCQuery.get_etcd_clusters(context[:product2].id))
    assert length(results) == 2
  end  

  test "find cluster by product id", context do
    results = Repo.all(PCQuery.get_product_clusters(context[:product].id))
    assert length(results) == 1
  end

  test "find clusters by product id", context do
    results = Repo.all(PCQuery.get_product_clusters(context[:product2].id))
    assert length(results) == 2
  end 

  test "find product by cluster", context do
    results = Repo.all(PCQuery.get_products_for_cluster(context[:cluster].id))
    assert length(results) == 1
  end

  test "find products by cluster", context do
    results = Repo.all(PCQuery.get_products_for_cluster(context[:etcd_cluster4].id))
    assert length(results) == 2
  end    
end