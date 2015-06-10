defmodule OpenAperture.Manager.DB.Models.ProductEnvironmentalVariable do
  @required_fields [:product_id, :name]
  @optional_fields [:product_environment_id, :value]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models
  alias OpenAperture.Manager.Repo

  schema "product_environmental_variables" do
    belongs_to :product,              Models.Product
    belongs_to :product_environment,  Models.ProductEnvironment
    field :name,                      :string
    field :value,                     :string
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
    |> validate_length(:name, min: 1)
  end

  def destroy_for_product(product), do: destroy_for_association(product, :environmental_variables)
  def destroy_for_environment(env), do: destroy_for_association(env, :environmental_variables)

  def destroy(pev) do
    Repo.delete pev
  end
end