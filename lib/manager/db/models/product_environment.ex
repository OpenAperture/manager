defmodule OpenAperture.Manager.DB.Models.ProductEnvironment do
  @required_fields [:product_id, :name]
  @optional_fields []
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models
  alias OpenAperture.Manager.Repo

  schema "product_environments" do
    belongs_to :product,                Models.Product
    has_many :environmental_variables,  Models.ProductEnvironmentalVariable
    field :name,                        :string
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
    |> validate_length(:name, min: 1)
  end

  def destroy_for_product(product), do: destroy_for_association(product, :environments)

  def destroy(pe) do
    Repo.transaction(fn ->
      Models.ProductEnvironmentalVariable.destroy_for_environment(pe)
      Repo.delete(pe)
    end) |> transaction_return
  end
end