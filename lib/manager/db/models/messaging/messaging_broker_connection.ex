defmodule OpenAperture.Manager.DB.Models.MessagingBrokerConnection do
  @required_fields [:messaging_broker_id, :username, :password, :host]
  @optional_fields [:virtual_host, :port]
  use OpenAperture.Manager.DB.Models.BaseModel

  alias OpenAperture.Manager.DB.Models.MessagingBroker

  schema "messaging_broker_connections" do
    belongs_to :messaging_broker, MessagingBroker
    field :username                       
    field :password       
    field :host   
    field :virtual_host
    field :port
    timestamps
  end

  def validate_changes(model_or_changeset, params) do
    cast(model_or_changeset,  params, @required_fields, @optional_fields)
  end

  def destroy(model) do
    Repo.delete! model
  end
end