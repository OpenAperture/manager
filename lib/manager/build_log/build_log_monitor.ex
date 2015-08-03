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

  @spec start_link() :: GenServer.on_start
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

  @spec init(:ok) :: {:ok, nil}
  def init(:ok) do
    {routing_key, root_exchange} = RoutingKey.build_hierarchy(Configuration.get_current_exchange_id, nil, nil)
    exchange_model = __MODULE__.get_exchange_model routing_key, root_exchange
    queue = %{ QueueBuilder.build_with_exchange("#{routing_key}.manager.build_logs.#{UUID.uuid1()}",
                               exchange_model,
                               [auto_delete: true],
                               [routing_key: "#{routing_key}.build_logs"])
              | auto_declare: true}

    connection_options = __MODULE__.get_connection_options
    
    subscribe(connection_options, queue, fn(payload, _meta, %{subscription_handler: subscription_handler, delivery_tag: delivery_tag}) -> 
      Logger.info("build log monitor: #{inspect payload}")
      handle_logs(payload)
      SubscriptionHandler.acknowledge(subscription_handler, delivery_tag)
    end)
    {:ok, nil}
  end

  @spec get_exchange_model(String.t, term) :: OpenAperture.Messaging.AMQP.Exchange.t
  def get_exchange_model(routing_key, root_exchange) do
    exchange_db = Repo.get(MessagingExchangeModel, Configuration.get_current_exchange_id)
    if exchange_db == nil do
      raise "Exchange #{Configuration.get_current_exchange_id} not found"
    end
    exchange_model = %OpenAperture.Messaging.AMQP.Exchange{
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
      exchange_model = %{exchange_model |
                                failover_name: failover_exchange_db.name, 
                                failover_routing_key: failover_routing_key, 
                                failover_root_exchange_name: failover_root_exchange.name}
    end
    exchange_model
  end

  @spec get_connection_options() :: OpenAperture.Messaging.AMQP.ConnectionOptions
  def get_connection_options do
    broker = Repo.get(MessagingBrokerModel, Configuration.get_current_broker_id)
    if broker == nil do
      raise "Broker #{Configuration.get_current_broker_id} not found"
    end
    connection_options_list = MessagingBrokerQuery.get_connections_for_broker(broker)
    connection_options_map = OpenAperture.Messaging.ConnectionOptionsResolver.resolve_connection_option_for_broker(connection_options_list)
    connection_options = %OpenAperture.Messaging.AMQP.ConnectionOptions{
                    id: connection_options_map.id, 
                    username: connection_options_map.username, 
                    password: OpenAperture.Manager.Controllers.MessagingBrokers.decrypt_password(connection_options_map.password), 
                    host: connection_options_map.host, 
                    port: connection_options_map.port, 
                    virtual_host: connection_options_map.virtual_host}

    if broker.failover_broker_id != nil do
      failover_broker = Repo.get(MessagingBrokerModel, broker.failover_broker_id)
      if failover_broker == nil do
        raise "Failover Broker #{broker.failover_broker_id} not found"
      end
      failover_connection_options_list = MessagingBrokerQuery.get_connections_for_broker(failover_broker)
      failover_connection_options = OpenAperture.Messaging.ConnectionOptionsResolver.resolve_connection_option_for_broker(failover_connection_options_list)
      connection_options = %{connection_options |
                    failover_id: failover_connection_options.id, 
                    failover_username: failover_connection_options.username, 
                    failover_password: OpenAperture.Manager.Controllers.MessagingBrokers.decrypt_password(failover_connection_options.password), 
                    failover_host: failover_connection_options.host, 
                    failover_port: failover_connection_options.port, 
                    failover_virtual_host: failover_connection_options.virtual_host}
    end
    connection_options
  end

  @spec handle_logs(term) :: :ok | {:error, term}
  def handle_logs(payload) do
    #Logger.debug("Broadcasting build logs for id: #{payload.workflow_id} #{inspect payload.logs}")
    OpenAperture.Manager.Endpoint.broadcast!("build_log:" <> payload.workflow_id, "build_log", %{logs: payload.logs})
  end
end
