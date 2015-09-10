defmodule OpenAperture.Manager.DB.Models.MessagingBroker do
  @required_fields [:name]
  @optional_fields [:failover_broker_id]
  use OpenAperture.Manager.DB.Models.BaseModel

  def cachable_type, do: true
  
  alias OpenAperture.Manager.DB.Models.MessagingBrokerConnection

  schema "messaging_brokers" do
    has_many :messaging_broker_connection, MessagingBrokerConnection
    field :name
    field :failover_broker_id, :integer
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