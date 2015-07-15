require Logger

defmodule OpenAperture.Manager.BuildLogMonitor do
	use GenServer

  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.AMQP.SubscriptionHandler
  alias OpenAperture.Manager.Configuration
  alias OpenAperture.Manager.RoutingKey
  alias OpenAperture.Manager.DB.Queries.MessagingBroker, as: MessagingBrokerQuery
  alias OpenAperture.Manager.DB.Models.MessagingBroker, as: MessagingBrokerModel
  alias OpenAperture.Manager.DB.Models.MessagingExchange, as: MessagingExchangeModel
  alias OpenAperture.Manager.Repo

  @connection_options nil
  use OpenAperture.Messaging

  
	def start_link() do
    if Application.get_env(OpenAperture.Manager, :build_log_monitor_autostart, true) do
      Logger.debug("[BuildLogMonitor] Starting...")
        case GenServer.start_link(__MODULE__, :ok, name: __MODULE__) do
	      {:ok, pid} ->
	        Logger.debug("[BuildLogMonitor] Startup Complete")
	        {:ok, pid}
	      {:error, reason} -> {:error, reason}
	    end
    else
      Logger.debug("[BuildLogMonitor] skipping startup: autostart disabled")
      Agent.start_link(fn -> nil end) #to return {:ok, pid} to the supervisor
    end
	end

  def init(:ok) do
    {routing_key, root_exchange} = RoutingKey.build_hierarchy(Configuration.get_current_exchange_id, nil, nil)
    exchange_db = Repo.get(MessagingExchangeModel, Configuration.get_current_exchange_id)
    exchange_model = %OpenAperture.Messaging.AMQP.Exchange{
                                name: exchange_db.name,
                                routing_key: routing_key, 
                                root_exchange_name: root_exchange.name
    }
    if exchange_db.failover_exchange_id != nil do
      {failover_routing_key, failover_root_exchange} = RoutingKey.build_hierarchy(exchange_db.failover_exchange_id, nil, nil)
      failover_exchange_db = Repo.get(MessagingExchangeModel, exchange_db.failover_exchange_id)
      exchange_model = %{exchange_model |
                                failover_name: failover_exchange_db.name, 
                                failover_routing_key: failover_routing_key, 
                                failover_root_exchange_name: failover_root_exchange.name}
    end
    queue = QueueBuilder.build_with_exchange("#{routing_key}.manager.build_logs.#{UUID.uuid1()}",
                               exchange_model,
                               [auto_delete: true],
                               [routing_key: "#{routing_key}.build_logs"])
    queue = %{queue | auto_declare: true}

    broker = Repo.get(MessagingBrokerModel, Configuration.get_current_broker_id)
    connection_options_list = MessagingBrokerQuery.get_connections_for_broker(broker)
    connection_options = OpenAperture.Messaging.ConnectionOptionsResolver.resolve_connection_option_for_broker(connection_options_list)
    options_map = %OpenAperture.Messaging.AMQP.ConnectionOptions{
                    id: connection_options.id, 
                    username: connection_options.username, 
                    password: OpenAperture.Manager.Controllers.MessagingBrokers.decrypt_password(connection_options.password), 
                    host: connection_options.host, 
                    port: connection_options.port, 
                    virtual_host: connection_options.virtual_host}

    if broker.failover_broker_id != nil do
      failover_broker = Repo.get(MessagingBrokerModel, broker.failover_broker_id)
      failover_connection_options_list = MessagingBrokerQuery.get_connections_for_broker(failover_broker)
      failover_connection_options = OpenAperture.Messaging.ConnectionOptionsResolver.resolve_connection_option_for_broker(failover_connection_options_list)
    
      options_map = %{options_map |
                    failover_id: failover_connection_options.id, 
                    failover_username: failover_connection_options.username, 
                    failover_password: OpenAperture.Manager.Controllers.MessagingBrokers.decrypt_password(failover_connection_options.password), 
                    failover_host: failover_connection_options.host, 
                    failover_port: failover_connection_options.port, 
                    failover_virtual_host: failover_connection_options.virtual_host}
    end
    
    subscribe(options_map, queue, fn(payload, _meta, %{subscription_handler: subscription_handler, delivery_tag: delivery_tag}) -> 
      Logger.info("build log monitor: #{inspect payload}")
      SubscriptionHandler.acknowledge(subscription_handler, delivery_tag)
    end)
    {:ok, nil}
  end
end