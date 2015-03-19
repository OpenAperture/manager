defmodule ProjectOmeletteManager.DB.Models.MessagingBroker do
  use Ecto.Model

  alias ProjectOmeletteManager.DB.Models.MessagingBrokerConnection

  schema "messaging_brokers" do
    has_many :messaging_broker_connection, MessagingBrokerConnection
    field :name
    field :failover_broker_id, :integer
    timestamps
  end

  ## Changesets
  def new(params \\ nil) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model_or_changeset, params \\ nil) do
    cast(model_or_changeset, params, ~w(name), ~w(failover_broker_id))
  end
end