defmodule OpenAperture.Manager.DB.Models.SystemEvent do
  @required_fields []
  @optional_fields [:type, :message, :severity, :data]

  use OpenAperture.Manager.DB.Models.BaseModel

  schema "system_events" do
    field :type
    field :message
    field :severity
    field :data
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end
  
  def destroy(model) do
    Repo.delete model
  end
end