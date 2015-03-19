defmodule ProjectOmeletteManager.DB.Models.MessagingExchangeBroker do
  use Ecto.Model

  alias ProjectOmeletteManager.DB.Models.MessagingBroker
  alias ProjectOmeletteManager.DB.Models.MessagingExchange

  schema "messaging_exchange_brokers" do
    belongs_to :messaging_broker,   MessagingBroker
    belongs_to :messaging_exchange,   MessagingExchange
    timestamps
  end

  ## Changesets
  def new(params \\ nil) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model_or_changeset, params \\ nil) do
    cast(model_or_changeset, params, ~w(messaging_broker_id messaging_exchange_id))
  end
end