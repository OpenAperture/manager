defmodule OpenAperture.Manager.DB.Models.AuthSourceUserRelation do
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.AuthSource
  alias OpenAperture.Manager.DB.Models.User

  schema "auth_sources_users_relations" do
    belongs_to :auth_source, AuthSource
    belongs_to :user, User

    timestamps
  end

  @required_fields [:auth_source_id, :user_id]

  def validate_changes(changeset, params \\ nil) do
    cast(changeset, params, @required_fields, [])
  end
end