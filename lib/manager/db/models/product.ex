defmodule OpenAperture.Manager.DB.Models.Product do
  @required_fields [:name]
  @optional_fields []
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models

  schema "products" do
    field :name                        # defaults to type :string
    has_many :environments,            Models.ProductEnvironment
    has_many :environmental_variables, Models.ProductEnvironmentalVariable
    has_many :product_clusters,        Models.ProductCluster
    has_many :product_components,      Models.ProductComponent
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
    |> validate_length(:name, min: 1)
  end

  def destroy(product) do
    Models.ProductEnvironmentalVariable.destroy_for_product(product)
    Models.ProductEnvironment.destroy_for_product(product)
    Models.ProductCluster.destroy_for_product(product)
    Models.ProductComponent.destroy_for_product(product)
    OpenAperture.Manager.Repo.delete(product)
  end
end