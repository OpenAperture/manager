require Logger

defmodule OpenAperture.Manager.BuildLogMonitor do
	use GenServer

  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.AMQP.SubscriptionHandler
  alias OpenAperture.ManagerApi
  alias OpenAperture.Manager.Configuration
  alias OpenAperture.Manager.RoutingKey

  @connection_options nil
  use OpenAperture.Messaging

  
	def start_link() do
    if Application.get_env(:openaperture_manager_overseer_api, :autostart, true) do
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

    options = OpenAperture.Messaging.ConnectionOptionsResolver.get_for_broker(ManagerApi.get_api, Configuration.get_current_broker_id)
    subscribe(options, queue, fn(payload, _meta, %{subscription_handler: subscription_handler, delivery_tag: delivery_tag}) -> 
      Logger.info("build log monitor: #{inspect payload}")
      SubscriptionHandler.acknowledge(subscription_handler, delivery_tag)
    end)
    {:ok, nil}
  end
end