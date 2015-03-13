#
# == product_component.ex
#
# This module contains the db schema the 'product_component' table
#
# == Contact
#
# Author::    Trantor (trantordevonly@perceptivesoftware.com)
# Copyright:: 2014 Lexmark International Technology S.A.  All rights reserved.
# License::   n/a
#
defmodule ProjectOmeletteManager.DB.Models.ProductComponent do
  @required_fields [:product_id, :name, :type]
  @optional_fields []
  use ProjectOmeletteManager.DB.Models.BaseModel

  alias ProjectOmeletteManager.DB.Models

  schema "product_components" do
    belongs_to :product,                 Models.Product
    has_many :product_component_options, Models.ProductComponentOption
    field :name,                         :string
    field :type,                         :string
    timestamps
  end

  defp validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
      |> validate_inclusion(:type, ["web_server", "db"])
  end

end
