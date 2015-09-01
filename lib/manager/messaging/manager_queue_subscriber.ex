defmodule OpenAperture.Manager.Messaging.ManagerQueue do

  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.AMQP.SubscriptionHandler
  alias OpenAperture.Manager.Configuration
  alias OpenAperture.Manager.RoutingKey
  alias OpenAperture.Manager.DB.Queries.MessagingBroker, as: MessagingBrokerQuery
  alias OpenAperture.Manager.DB.Models.MessagingBroker, as: MessagingBrokerModel
  alias OpenAperture.Manager.DB.Models.MessagingExchange, as: MessagingExchangeModel
  alias OpenAperture.Manager.Repo
  alias OpenAperture.Manager.ResourceCache.CachedResource
  alias OpenAperture.ManagerApi.SystemEvent

  @connection_options nil
  use OpenAperture.Messaging

  @spec build_and_subscribe(String.t, fun) :: :ok
  def build_and_subscribe(queue_name, fun) do
    {routing_key, root_exchange} = RoutingKey.build_hierarchy(Configuration.get_current_exchange_id, nil, nil)
    exchange = __MODULE__.get_exchange routing_key, root_exchange
    queue = %{ QueueBuilder.build_with_exchange("#{routing_key}.manager.#{queue_name}.#{UUID.uuid1()}",
                               exchange,
                               [auto_delete: true],
                               [routing_key: "#{routing_key}.#{queue_name}"])
              | auto_declare: true}

    connection_options = __MODULE__.messaging_connection_options
    
    subscribe(connection_options, queue, fn(payload, _meta, %{subscription_handler: subscription_handler, delivery_tag: delivery_tag}) -> 
      try do
        fun.(payload)
            catch
        :exit, code   ->
          error_msg = "Message #{delivery_tag} (for queue #{queue_name}) Exited with code #{inspect code}.  Payload:  #{inspect payload}"
          Logger.error(error_msg)
          event = %{
            unique: true,
            type: :unhandled_exception,
            severity: :error,
            data: %{
              component: :overseer,
              exchange_id: Configuration.get_current_exchange_id,
              hostname: System.get_env("HOSTNAME")
            },
            message: error_msg
          }
          SystemEvent.create_system_event!(ManagerApi.get_api, event)
        :throw, value ->
          error_msg = "Message #{delivery_tag} (for queue #{queue_name}) Throw called with #{inspect value}.  Payload:  #{inspect payload}"
          Logger.error(error_msg)
          event = %{
            unique: true,
            type: :unhandled_exception,
            severity: :error,
            data: %{
              component: :overseer,
              exchange_id: Configuration.get_current_exchange_id,
              hostname: System.get_env("HOSTNAME")
            },
            message: error_msg
          }
          SystemEvent.create_system_event!(ManagerApi.get_api, event)
        what, value   ->
          error_msg = "Message #{delivery_tag} (for queue #{queue_name}) Caught #{inspect what} with #{inspect value}.  Payload:  #{inspect payload}"
          Logger.error(error_msg)
          event = %{
            unique: true,
            type: :unhandled_exception,
            severity: :error,
            data: %{
              component: :overseer,
              exchange_id: Configuration.get_current_exchange_id,
              hostname: System.get_env("HOSTNAME")
            },
            message: error_msg
          }
          SystemEvent.create_system_event!(ManagerApi.get_api, event)\
      end
      SubscriptionHandler.acknowledge(subscription_handler, delivery_tag)
    end)
    :ok
  end

  @spec get_exchange(String.t, term) :: OpenAperture.Messaging.AMQP.Exchange.t
  def get_exchange(routing_key, root_exchange) do
    exchange_db = Repo.get(MessagingExchangeModel, Configuration.get_current_exchange_id)
    if exchange_db == nil do
      raise "Exchange #{Configuration.get_current_exchange_id} not found"
    end
    exchange = %OpenAperture.Messaging.AMQP.Exchange{
                                name: exchange_db.name,
                                routing_key: routing_key,
                                root_exchange_name: root_exchange.name
    }
    if exchange_db.failover_exchange_id != nil do
      {failover_routing_key, failover_root_exchange} = RoutingKey.build_hierarchy(exchange_db.failover_exchange_id, nil, nil)
      failover_exchange_db = Repo.get(MessagingExchangeModel, exchange_db.failover_exchange_id)
      if failover_exchange_db == nil do
        raise "Failover Exchange #{exchange_db.failover_exchange_id} not found"
      end
      exchange = %{exchange |
                                failover_name: failover_exchange_db.name, 
                                failover_routing_key: failover_routing_key, 
                                failover_root_exchange_name: failover_root_exchange.name}
    end
    exchange
  end

  @spec messaging_connection_options() :: OpenAperture.Messaging.AMQP.ConnectionOptions
  def messaging_connection_options do
    broker = CachedResource.get(MessagingBrokerModel, Configuration.get_current_broker_id, fn -> Repo.get(MessagingBrokerModel, Configuration.get_current_broker_id) end)
    if broker == nil do
      raise "Broker #{Configuration.get_current_broker_id} not found"
    end
    connection_options_list = MessagingBrokerQuery.get_connections_for_broker(broker)
    connection_options_map = OpenAperture.Messaging.ConnectionOptionsResolver.resolve_connection_option_for_broker(connection_options_list)
    connection_options = %OpenAperture.Messaging.AMQP.ConnectionOptions{
                    id: connection_options_map.id, 
                    username: connection_options_map.username, 
                    password: OpenAperture.Manager.Controllers.FormatHelper.decrypt_value(connection_options_map.password), 
                    host: connection_options_map.host, 
                    port: connection_options_map.port, 
                    virtual_host: connection_options_map.virtual_host}

    if broker.failover_broker_id != nil do
      failover_broker = CachedResource.get(MessagingBrokerModel, broker.failover_broker_id, fn -> Repo.get(MessagingBrokerModel, broker.failover_broker_id) end)
      if failover_broker == nil do
        raise "Failover Broker #{broker.failover_broker_id} not found"
      end
      failover_connection_options_list = MessagingBrokerQuery.get_connections_for_broker(failover_broker)
      failover_connection_options = OpenAperture.Messaging.ConnectionOptionsResolver.resolve_connection_option_for_broker(failover_connection_options_list)
      connection_options = %{connection_options |
                    failover_id: failover_connection_options.id, 
                    failover_username: failover_connection_options.username, 
                    failover_password: OpenAperture.Manager.Controllers.FormatHelper.decrypt_value(failover_connection_options.password), 
                    failover_host: failover_connection_options.host, 
                    failover_port: failover_connection_options.port, 
                    failover_virtual_host: failover_connection_options.virtual_host}
    end
    connection_options
  end

end