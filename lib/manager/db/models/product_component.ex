defmodule OpenAperture.Manager.DB.Models.ProductComponent do
  @required_fields [:product_id, :name, :type]
  @optional_fields []
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models

  schema "product_components" do
    belongs_to :product,                 Models.Product
    has_many :product_component_options, Models.ProductComponentOption
    field :name,                         :string
    field :type,                         :string
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
      |> validate_inclusion(:type, ["web_server", "db"])
  end

end
