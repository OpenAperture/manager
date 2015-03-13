defmodule ProjectOmeletteManager.DB.Models.ProductEnvironment do
  @required_fields [:product_id, :name]
  @optional_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models

  schema "product_environments" do
    belongs_to :product,                Models.Product
    has_many :environmental_variables,  Models.ProductEnvironmentalVariable
    field :name,                        :string
    timestamps
  end

  defp validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end
end