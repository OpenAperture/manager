defmodule ProjectOmeletteManager.DB.Models.MessagingExchange do
  use Ecto.Model

  schema "messaging_exchanges" do
    field :name   
    timestamps
  end

  ## Changesets
  def new(params \\ nil) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model_or_changeset, params \\ nil) do
    cast(model_or_changeset, params, ~w(name))
  end
end