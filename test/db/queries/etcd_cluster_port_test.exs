defmodule DB.Queries.EtcdClusterPort.Test do
  use ExUnit.Case, async: false

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.ProductComponent
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Models.EtcdClusterPort

  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Queries.EtcdClusterPort, as: EtcdClusterQuery

  setup _context do
    on_exit _context, fn ->
      Repo.delete_all(EtcdClusterPort)
      Repo.delete_all(EtcdCluster)
      Repo.delete_all(ProductComponent)
      Repo.delete_all(Product)
    end
  end

  test "get_ports_by_cluster - success" do
    cluster = EtcdCluster.new(%{etcd_token: "123abc"}) |> Repo.insert!

    product = Product.new(%{name: "test product"}) |> Repo.insert!
    component = ProductComponent.new(%{product_id: product.id, type: "web_server", name: "woah now"}) |> Repo.insert!

    cluster_port_values = %{
      etcd_cluster_id: cluster.id,
      product_component_id: component.id,
      port: 12345
    }

    cluster_port = EtcdClusterPort.new(cluster_port_values) |> Repo.insert!
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
    cluster = EtcdCluster.new(%{etcd_token: "123abc"}) |> Repo.insert!

    product = Product.new(%{name: "test product"}) |> Repo.insert!
    component = ProductComponent.new(%{product_id: product.id, type: "web_server", name: "woah now"}) |> Repo.insert!

    cluster_port_values = %{
      etcd_cluster_id: cluster.id,
      product_component_id: component.id,
      port: 12345
    }

    cluster_port = EtcdClusterPort.new(cluster_port_values) |> Repo.insert!
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