require Logger
defmodule OpenAperture.Manager.DB.Models.ProductCluster do
  @required_fields [:product_id, :etcd_cluster_id]
  @optional_fields [:primary_ind]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.Product
  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.Repo


  schema "product_clusters" do
    belongs_to :product,                Product
    belongs_to :etcd_cluster,           EtcdCluster
    field :primary_ind,                :boolean
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
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