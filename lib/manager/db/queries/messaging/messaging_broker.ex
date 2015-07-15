defmodule OpenAperture.Manager.DB.Queries.MessagingBroker do
  use Ecto.Model

  alias OpenAperture.Manager.Repo

  def get_connections_for_broker(broker) do
  	Repo.all assoc(broker, :messaging_broker_connection)
  end
end