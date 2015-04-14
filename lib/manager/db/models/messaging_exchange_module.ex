defmodule OpenAperture.Manager.DB.Models.MessagingExchangeModule do
  use Ecto.Model

  alias OpenAperture.Manager.DB.Models.MessagingExchange

  schema "messaging_exchange_modules" do
    belongs_to :messaging_exchange,   MessagingExchange
    field :hostname
    field :type
    field :status
    field :workload
    timestamps
  end

  ## Changesets
  def new(params \\ nil) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model_or_changeset, params \\ nil) do
    cast(model_or_changeset, params, ~w(messaging_exchange_id hostname type status workload))
  end
end