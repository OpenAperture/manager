defmodule OpenAperture.Manager.ResourceCache.Publisher do
  alias OpenAperture.Manager.Repo
  alias OpenAperture.ManagerApi
  require Repo


  @connection_options nil
  use OpenAperture.Messaging

  alias OpenAperture.Manager.Configuration
  alias OpenAperture.Manager.ResourceCache.CachedResource
  alias OpenAperture.Manager.DB.Models.SystemComponent
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.ConnectionOptionsResolver

  @type qc :: {Queue.t, ConnectionOptions.t}

  @logprefix "[ResourceCache.Publisher]"

  @spec cache_clear(CachedResource.ct, any) :: :ok
  def cache_clear(type, key) do
    manager_components
    |> Enum.map(&(&1.messaging_exchange_id))
    |> Enum.uniq
    |> Enum.map(&get_exchange_queue(&1))
    |> Enum.map(&publish_to_queue(&1, %{type: type, key: key}))
    Logger.debug "#{@logprefix} Published clear for #{type} #{key}"
    :ok
  end

  @spec manager_components :: [map]
  defp manager_components do
    CachedResource.get(SystemComponent, :all, fn -> Repo.all(SystemComponent) end)
    |> Enum.filter(&(&1.type == "manager"))
  end

  @spec get_exchange_queue(integer) :: qc
  defp get_exchange_queue(exchange_id), do: CachedResource.get(:exchange_cache_queues, exchange_id, fn -> build_queue(exchange_id) end)

  @spec publish_to_queue(qc, any) :: :ok | {:error, String.t}
  defp publish_to_queue({queue, options}, payload), do: __MODULE__.publish(options, queue, payload)

  @spec build_queue(integer) :: qc
  defp build_queue(exchange_id) do 
    queue = QueueBuilder.build(ManagerApi.get_api, "cache", exchange_id)
    options = ConnectionOptionsResolver.resolve(ManagerApi.get_api,
                                                Configuration.get_current_broker_id,
                                                Configuration.get_current_exchange_id,
                                                exchange_id)
    {queue, options}
  end
end