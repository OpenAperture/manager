defmodule OpenAperture.Manager.DB.Models.AuthSource do
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.AuthSourceUserRelation

  schema "auth_sources" do
    field :name
    field :token_info_url
    field :email_field_name
    field :first_name_field_name
    field :last_name_field_name

    has_many :user_relations, AuthSourceUserRelation

    has_many :users, through: [:user_relations, :user]

    timestamps
  end

  @required_fields [:token_info_url, :email_field_name, :first_name_field_name, :last_name_field_name]
  @optional_fields [:name]

  def validate_changes(changeset, params \\ nil) do
    cast(changeset, params, @required_fields, @optional_fields)
    |> validate_length(:token_info_url, min: 8)
    |> validate_length(:email_field_name, min: 1)
    |> validate_length(:first_name_field_name, min: 1)
    |> validate_length(:last_name_field_name, min: 1)
  end
end