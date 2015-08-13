defmodule OpenAperture.Manager.DB.Models.SystemEvent do
  alias OpenAperture.Manager.DB.Models.User

  @required_fields [
    :type, 
    :severity, 
  ]
  @optional_fields [
    :message, 
    :data, 
    :dismissed_at,
    :dismissed_by_id,
    :dismissed_reason,
    :assigned_at,
    :assignee_id,
    :assigned_by_id
  ]

  use OpenAperture.Manager.DB.Models.BaseModel

  schema "system_events" do
    belongs_to :assignee, User
    belongs_to :assigned_by, User
    belongs_to :dismissed_by, User
    field :type
    field :message
    field :severity
    field :data
    field :dismissed_at, Ecto.DateTime
    field :dismissed_reason
    field :assigned_at, Ecto.DateTime
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
    |> validate_length(:type, min: 1)
    |> validate_length(:severity, min: 1)    
  end
  
  def destroy(model) do
    Repo.delete model
  end
end