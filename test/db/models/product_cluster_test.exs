defmodule DB.Models.ProductCluster.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Models.ProductCluster

  setup _context do
    product = Product.new(%{name: "test product"}) |> Repo.insert!
    etcd_cluster = EtcdCluster.new(%{etcd_token: "abc123"}) |> Repo.insert!

    product2 = Product.new(%{name: "test product2"}) |> Repo.insert!
    etcd_cluster2 = EtcdCluster.new(%{etcd_token: "bcd234"}) |> Repo.insert!
    etcd_cluster3 = EtcdCluster.new(%{etcd_token: "zyx987"}) |> Repo.insert!

    on_exit _context, fn ->
      Repo.delete_all(ProductCluster)
      Repo.delete_all(Product)
      Repo.delete_all(EtcdCluster)
    end

    {:ok, [product: product, product2: product2, cluster: etcd_cluster, etcd_cluster2: etcd_cluster2, etcd_cluster3: etcd_cluster3]}
  end

  test "validate - fail to create cluster with missing values" do
    changeset = ProductCluster.new(%{})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :product_id)
    assert Keyword.has_key?(changeset.errors, :etcd_cluster_id)
  end

  test "validate - success", context do
    changeset = ProductCluster.new(%{product_id: context[:product].id, etcd_cluster_id: context[:cluster].id})
    assert changeset.valid?
  end

  test "single cluster", context do
    product_cluster = %{product_id: context[:product].id, etcd_cluster_id: context[:cluster].id}

    new_cluster = ProductCluster.new(product_cluster) |> Repo.insert!

    retrieved_cluster = Repo.get(ProductCluster, new_cluster.id)

    assert retrieved_cluster == new_cluster
    assert retrieved_cluster.product_id == context[:product].id
    assert retrieved_cluster.etcd_cluster_id == context[:cluster].id
  end

  test "multiple clusters", context do
    product_cluster = ProductCluster.new(%{product_id: context[:product2].id, etcd_cluster_id: context[:etcd_cluster2].id}) |> Repo.insert!
    product_cluster1 = ProductCluster.new(%{product_id: context[:product2].id, etcd_cluster_id: context[:etcd_cluster3].id}) |> Repo.insert!

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
