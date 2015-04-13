defmodule OpenAperture.Manager.DB.Models.MessagingExchange do
  use Ecto.Model

  schema "messaging_exchanges" do
    field :name
    field :failover_exchange_id, :integer
    timestamps
  end

  ## Changesets
  def new(params \\ nil) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model_or_changeset, params \\ nil) do
    cast(model_or_changeset, params, ~w(name), ~w(failover_exchange_id))
  end
end