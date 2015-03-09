defmodule DB.Queries.EtcdClusterPort.Test do
  use ExUnit.Case

  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.ProductComponent
  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Models.EtcdClusterPort

  alias ProjectOmeletteManager.Repo
  alias ProjectOmeletteManager.DB.Queries.EtcdClusterPort, as: EtcdClusterQuery

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(EtcdClusterPort)
      Repo.delete_all(EtcdCluster)
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end
  end

  test "get_ports_by_cluster - success" do
    cluster = Repo.insert(%EtcdCluster{etcd_token: "123abc"})

    product = Repo.insert(%Product{name: "test product"})
    component = Repo.insert(%ProductComponent{product_id: product.id, type: "crazy junk", name: "woah now"})

    cluster_port = %EtcdClusterPort{
      etcd_cluster_id: cluster.id,
      product_component_id: component.id,
      port: 12345
    }

    cluster_port = Repo.insert(cluster_port)
    results = Repo.all(EtcdClusterQuery.get_ports_by_cluster(cluster.id))
    assert results != nil
    assert length(results) == 1
    assert List.first(results).id == cluster_port.id
  end

  test "get_ports_by_cluster - failure" do
    results = Repo.all(EtcdClusterQuery.get_ports_by_cluster(1234567890))
    assert results != nil
    assert length(results) == 0
  end

  test "get_ports_by_component - success" do
    cluster = Repo.insert(%EtcdCluster{etcd_token: "123abc"})

    product = Repo.insert(%Product{name: "test product"})
    component = Repo.insert(%ProductComponent{product_id: product.id, type: "crazy junk", name: "woah now"})

    cluster_port = %EtcdClusterPort{
      etcd_cluster_id: cluster.id,
      product_component_id: component.id,
      port: 12345
    }

    cluster_port = Repo.insert(cluster_port)
    results = Repo.all(EtcdClusterQuery.get_ports_by_component(component.id))
    assert results != nil
    assert length(results) == 1
    assert List.first(results).id == cluster_port.id
  end

  test "get_ports_by_component - failure" do
    results = Repo.all(EtcdClusterQuery.get_ports_by_component(1234567890))
    assert results != nil
    assert length(results) == 0
  end  
end