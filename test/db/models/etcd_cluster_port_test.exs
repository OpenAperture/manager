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

  test "validate - fail to create cluster_port with missing values", context do
    cluster_port = %EtcdClusterPort{}

    result = EtcdClusterPort.validate(cluster_port)
    assert map_size(result) != 0
    assert Map.has_key?(result, :etcd_cluster_id)
    assert Map.has_key?(result, :product_component_id)
    assert Map.has_key?(result, :port)
  end

  test "validate - success", context do
    cluster = Repo.insert(%EtcdCluster{etcd_token: "123abc"})

    product = Repo.insert(%Product{name: "test product"})
    component = Repo.insert(%ProductComponent{product_id: product.id, type: "crazy junk", name: "woah now"})

    cluster_port = %EtcdClusterPort{
      etcd_cluster_id: cluster.id,
      product_component_id: component.id,
      port: 12345
    }

    result = EtcdClusterPort.validate(cluster_port)
    assert result == nil
  end

  test "insert - success", context do
    cluster = Repo.insert(%EtcdCluster{etcd_token: "123abc"})

    product = Repo.insert(%Product{name: "test product"})
    component = Repo.insert(%ProductComponent{product_id: product.id, type: "crazy junk", name: "woah now"})

    cluster_port = %EtcdClusterPort{
      etcd_cluster_id: cluster.id,
      product_component_id: component.id,
      port: 12345
    }

    result = Repo.insert(cluster_port)
    assert result != nil
    assert result.id != nil
  end  
end