defmodule OpenAperture.Manager.DB.Models.Router.DeletedAuthority do
  use OpenAperture.Manager.DB.Models.BaseModel

  schema "deleted_authorities" do
    field :hostname, :string
    field :port,     :integer

    timestamps
  end

  @required_fields ~w(hostname port)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If `params` are nil, an invalid changeset is returned
  with no validation performed.
  """

  def validate_changes(model_or_changeset, params) do
    model_or_changeset
    |> cast(params, @required_fields, @optional_fields)
  end
end