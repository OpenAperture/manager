defmodule OpenAperture.Manager.DB.Models.Router.Authority do
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.Router.Route

  schema "authorities" do
    field    :hostname, :string
    field    :port,     :integer

    has_many :routes,   Route

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
    |> validate_length(:hostname, min: 1, message: "hostname cannot be blank")
    |> validate_inclusion(:port, 1..65535, message: "invalid port number")
  end

  def destroy(model) do
    Repo.delete! model
  end
end
