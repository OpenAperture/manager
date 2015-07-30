defmodule OpenAperture.Manager.DB.Models.MessagingExchangeBroker do
  @required_fields [:messaging_broker_id, :messaging_exchange_id]
  @optional_fields []
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.MessagingBroker
  alias OpenAperture.Manager.DB.Models.MessagingExchange

  schema "messaging_exchange_brokers" do
    belongs_to :messaging_broker,   MessagingBroker
    belongs_to :messaging_exchange,   MessagingExchange
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end

  def destroy(model) do
    Repo.delete! model
  end
end