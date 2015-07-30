defmodule OpenAperture.Manager.DB.Models.MessagingExchange do
  @required_fields [:name]
  @optional_fields [:failover_exchange_id, :parent_exchange_id, :routing_key_fragment]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.MessagingExchangeBroker
  alias OpenAperture.Manager.DB.Models.MessagingExchangeModule
  alias OpenAperture.Manager.DB.Models.SystemComponent

  schema "messaging_exchanges" do
    has_many :messaging_exchange_brokers, MessagingExchangeBroker
    has_many :messaging_exchange_modules, MessagingExchangeModule
    has_many :system_components, SystemComponent
    field :name
    field :failover_exchange_id, :integer
    field :parent_exchange_id, :integer
    field :routing_key_fragment
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
    |> validate_length(:name, min: 1)
  end

  def destroy(model) do
    Repo.delete! model
  end
end