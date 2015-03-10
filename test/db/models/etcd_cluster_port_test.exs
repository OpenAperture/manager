defmodule DB.Models.EtcdClusterPort.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductComponent
  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Models.EtcdClusterPort
  alias ProjectOmeletteManager.Repo

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(EtcdClusterPort)
      Repo.delete_all(EtcdCluster)
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end
  end

  test "validate - fail to create cluster_port with missing values" do
    {status, errors} = EtcdClusterPort.vinsert(%EtcdClusterPort{})
    assert status == :error
    assert Keyword.has_key?(errors, :etcd_cluster_id)
    assert Keyword.has_key?(errors, :product_component_id)
    assert Keyword.has_key?(errors, :port)
  end

  test "validate - success" do
    {:ok, cluster} = EtcdCluster.vinsert(%EtcdCluster{etcd_token: "123abc"})

    {:ok, product} = Product.vinsert(%Product{name: "test product"})
    {:ok, component} = ProductComponent.vinsert(%ProductComponent{product_id: product.id, type: "crazy junk", name: "woah now"})

    cluster_port = %EtcdClusterPort{
      etcd_cluster_id: cluster.id,
      product_component_id: component.id,
      port: 12345
    }

    {status, _result} = EtcdClusterPort.vinsert(cluster_port)
    assert status == :ok
  end

  test "insert - success" do
    {:ok, cluster} = EtcdCluster.vinsert(%EtcdCluster{etcd_token: "123abc"})

    {:ok, product} = Product.vinsert(%Product{name: "test product"})
    {:ok, component} = ProductComponent.vinsert(%ProductComponent{product_id: product.id, type: "crazy junk", name: "woah now"})

    cluster_port = %EtcdClusterPort{
      etcd_cluster_id: cluster.id,
      product_component_id: component.id,
      port: 12345
    }

    {status, result} = EtcdClusterPort.vinsert(cluster_port)
    assert status == :ok
    assert result.id != nil
  end  
end