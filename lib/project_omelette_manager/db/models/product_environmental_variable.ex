defmodule ProjectOmeletteManager.DB.Models.ProductEnvironmentalVariable do
  @required_fields [:product_id, :name]
  @optional_fields [:product_environment_id, :value]
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models

  schema "product_environmental_variables" do
    belongs_to :product,              Models.Product
    belongs_to :product_environment,  Models.ProductEnvironment
    field :name,                      :string
    field :value,                     :string
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end
end