defmodule ProjectOmeletteManager.DB.Models.Product do
  @required_fields [:name]
  @optional_fields []
  @member_of_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models

  schema "products" do
    field :name                        # defaults to type :string
    has_many :environments,            Models.ProductEnvironment
    has_many :environmental_variables, Models.ProductEnvironmentalVariable
    has_many :product_clusters,        Models.ProductCluster
    has_many :product_components,      Models.ProductComponent
    timestamps
  end
end