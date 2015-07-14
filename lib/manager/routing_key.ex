defmodule OpenAperture.Manager.RoutingKey do
	alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.DB.Models.MessagingExchange

	
  def build_hierarchy(exchange_id, routing_key, root_exchange) do
    if exchange_id == nil do
      {routing_key, root_exchange}
    else
      exchange = Repo.get(MessagingExchange, exchange_id)
      cond do
        exchange == nil -> build_hierarchy(routing_key.parent_exchange_id, routing_key, root_exchange)
        routing_key == nil -> build_hierarchy(exchange.parent_exchange_id, exchange.routing_key_fragment, exchange)
        true -> build_hierarchy(exchange.parent_exchange_id, "#{exchange.routing_key_fragment}.#{routing_key}", exchange)
      end
    end
  end
end