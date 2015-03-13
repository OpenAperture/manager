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
    changeset = EtcdClusterPort.new(%{})
    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :etcd_cluster_id)
    assert Keyword.has_key?(changeset.errors, :product_component_id)
    assert Keyword.has_key?(changeset.errors, :port)
  end

  test "validate - success" do
    cluster = EtcdCluster.new(%{etcd_token: "123abc"}) |> Repo.insert
    product = Product.new(%{name: "test product"}) |> Repo.insert
    component = ProductComponent.new(%{product_id: product.id, type: "web_server", name: "woah now"}) |> Repo.insert

    changeset = EtcdClusterPort.new(%{etcd_cluster_id: cluster.id, product_component_id: component.id, port: 12345})
    assert changeset.valid?
  end

  test "insert - success" do
    cluster = EtcdCluster.new(%{etcd_token: "123abc"}) |> Repo.insert
    product = Product.new(%{name: "test product"}) |> Repo.insert
    component = ProductComponent.new(%{product_id: product.id, type: "web_server", name: "woah now"}) |> Repo.insert

    result = EtcdClusterPort.new(%{etcd_cluster_id: cluster.id, product_component_id: component.id, port: 12345}) |> Repo.insert
    assert result != nil
    assert result.id != nil
  end  
end