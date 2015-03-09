#
# == etcd_cluster_port.ex
#
# This module contains the db schema the 'etcd_cluster_ports' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2015 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Models.EtcdClusterPort do
  @required_fields [:etcd_cluster_id, :product_component_id, :port]
  @optional_fields []
  @member_of_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel


  alias ProjectOmeletteManager.DB.Models.EtcdCluster
  alias ProjectOmeletteManager.DB.Models.ProductComponent

  schema "etcd_cluster_ports" do
    belongs_to :etcd_cluster,       EtcdCluster
    belongs_to :product_component,  ProductComponent
    field :port,                    :integer
    timestamps
  end

end