require Logger

defmodule OpenAperture.Manager.BuildLogMonitor do
	use GenServer

  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.AMQP.SubscriptionHandler
  alias OpenAperture.ManagerApi
  alias OpenAperture.Manager.Configuration
  alias OpenAperture.Manager.RoutingKey
  alias OpenAperture.Manager.DB.Queries.MessagingBroker, as: MessagingBrokerQuery
  alias OpenAperture.Manager.DB.Models.MessagingBroker, as: MessagingBrokerModel
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
    {routing_key, _} = RoutingKey.build_hierarchy(Configuration.get_current_exchange_id, nil, nil)

    queue = QueueBuilder.build(ManagerApi.get_api,
                               "#{routing_key}.manager.build_logs.#{UUID.uuid1()}",
                               Configuration.get_current_exchange_id,
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
    
      options_map = %{options_map |
                    failover_id: failover_broker.id, 
                    failover_username: failover_broker.username, 
                    failover_password: OpenAperture.Manager.Controllers.MessagingBrokers.decrypt_password(failover_broker.password), 
                    failover_host: failover_broker.host, 
                    failover_port: failover_broker.port, 
                    failover_virtual_host: failover_broker.virtual_host}
    end
    
    subscribe(options_map, queue, fn(payload, _meta, %{subscription_handler: subscription_handler, delivery_tag: delivery_tag}) -> 
      Logger.info("build log monitor: #{inspect payload}")
      SubscriptionHandler.acknowledge(subscription_handler, delivery_tag)
    end)
    {:ok, nil}
  end
end