defmodule OpenAperture.Manager.DB.Models.ProductComponentOption do
  @required_fields [:product_component_id, :name]
  @optional_fields [:value]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.ProductComponent

  schema "product_component_options" do
    belongs_to :product_component,     ProductComponent
    field :name,                       :string
    field :value,                      :string    
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end

  def destroy_for_product_component(product_component) do
    OpenAperture.Manager.Repo.delete_all assoc(product_component, :product_component_options)
  end
end