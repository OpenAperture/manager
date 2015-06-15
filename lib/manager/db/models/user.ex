defmodule OpenAperture.Manager.DB.Models.User do
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.AuthSourceUserRelation

  schema "users" do
    field :first_name
    field :last_name
    field :email

    has_many :auth_source_relations, AuthSourceUserRelation
    has_many :auth_sources, through: [:auth_source_relations, :auth_source]

    timestamps
  end

  @required_fields [:first_name, :last_name, :email]

  def validate_changes(changeset, params \\ nil) do
    cast(changeset, params, @required_fields, [])
    |> validate_length(:first_name, min: 1)
    |> validate_length(:last_name, min: 1)
    |> validate_length(:email, min: 6)
    |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/)
    |> validate_unique(:email, on: OpenAperture.Manager.Repo)
  end
end
