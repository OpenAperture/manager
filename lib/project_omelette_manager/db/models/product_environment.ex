defmodule ProjectOmeletteManager.DB.Models.ProductEnvironment do
  @required_fields [:product_id, :name]
  @optional_fields []
  @member_of_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models

  schema "product_environments" do
    belongs_to :product,                Models.Product
    has_many :environmental_variables,  Models.ProductEnvironmentalVariable
    field :name,                        :string
    timestamps
  end
end