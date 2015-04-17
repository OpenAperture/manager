defmodule OpenAperture.Manager.DB.Models.EtcdClusterPort do
  @required_fields [:etcd_cluster_id, :product_component_id, :port]
  @optional_fields []
  use OpenAperture.Manager.DB.Models.BaseModel


  alias OpenAperture.Manager.DB.Models.EtcdCluster
  alias OpenAperture.Manager.DB.Models.ProductComponent

  schema "etcd_cluster_ports" do
    belongs_to :etcd_cluster,       EtcdCluster
    belongs_to :product_component,  ProductComponent
    field :port,                    :integer
    timestamps
  end
  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end

end