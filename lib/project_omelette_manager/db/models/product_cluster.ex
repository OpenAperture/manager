#
# == product_cluster.ex
#
# This module contains the db schema the 'product_clusters' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
require Logger
defmodule ProjectOmeletteManager.DB.Models.ProductCluster do
  @required_fields [:product_id, :etcd_cluster_id]
  @optional_fields [:primary_ind]
  @member_of_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models.Product
  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.Repo


  schema "product_clusters" do
    belongs_to :product,                Product
    belongs_to :etcd_cluster,           EtcdCluster
    field :primary_ind,                :boolean
  end
  

  def deallocate_ports_for_component(product_cluster, component) do
    cluster = Repo.get(EtcdCluster, product_cluster.etcd_cluster_id)
    EtcdCluster.deallocate_ports_for_component(cluster, component)
  end

  def allocate_ports_for_component(product_cluster, component, num_ports) do
    if num_ports > 0 do
      cluster = Repo.get(EtcdCluster, product_cluster.etcd_cluster_id)
      etcd_ports = EtcdCluster.allocate_ports(cluster, component, num_ports, [])

      Enum.reduce etcd_ports, [], fn(etcd_port, ports) ->
        ports ++ [etcd_port.port]
      end
    else
      []
    end
  end
end