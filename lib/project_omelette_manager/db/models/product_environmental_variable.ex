defmodule ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable do
  @required_fields [:product_id, :name]
  @optional_fields [:product_environment_id, :value]
  @member_of_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models

  schema "product_environmental_variables" do
    belongs_to :product,              Models.Product
    belongs_to :product_environment,  Models.ProductEnvironment
    field :name,                      :string
    field :value,                     :string
    timestamps
  end
end