defmodule OpenAperture.Manager.DB.Models.MessagingExchange do
  use Ecto.Model

  alias OpenAperture.Manager.DB.Models.MessagingExchangeBroker
  alias OpenAperture.Manager.DB.Models.MessagingExchangeModule

  schema "messaging_exchanges" do
    has_many :messaging_exchange_brokers, MessagingExchangeBroker
    has_many :messaging_exchange_modules, MessagingExchangeModule
    field :name
    field :failover_exchange_id, :integer
    field :parent_exchange_id, :integer
    field :routing_key_fragment
    timestamps
  end

  ## Changesets
  def new(params \\ nil) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model_or_changeset, params \\ nil) do
    cast(model_or_changeset, params, ~w(name), ~w(failover_exchange_id parent_exchange_id routing_key_fragment))
  end
end