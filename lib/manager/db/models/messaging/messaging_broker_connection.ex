defmodule OpenAperture.Manager.DB.Models.MessagingBrokerConnection do
  use Ecto.Model

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

  ## Changesets
  def new(params \\ nil) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(model_or_changeset, params \\ nil) do
    cast(model_or_changeset, params, ~w(messaging_broker_id username password host), ~w(virtual_host port))
  end

  def destroy(model) do
    Repo.delete model
  end
end