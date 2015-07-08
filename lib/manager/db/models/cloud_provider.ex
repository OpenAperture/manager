defmodule OpenAperture.Manager.DB.Models.CloudProvider do
  @required_fields [:name, :type, :configuration]
  @optional_fields []

  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.EtcdCluster

  schema "cloud_providers" do
    has_many :etcd_clusters, EtcdCluster
    field :name                        # defaults to type :string
    field :type                        # defaults to type :string
    field :configuration               # defaults to type :string
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
    |> validate_length(:name, min: 1)
    |> validate_length(:type, min: 1)
  end

  def destroy(model) do
    Repo.delete model
  end
end