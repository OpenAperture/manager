defmodule OpenAperture.Manager.ResourceCache.Publisher do
  alias OpenAperture.Manager.Repo
  require Repo


  @connection_options nil
  use OpenAperture.Messaging

  alias OpenAperture.Manager.Configuration
  alias OpenAperture.Manager.ResourceCache.CachedResource
  alias OpenAperture.Manager.DB.Models.SystemComponent
  alias OpenAperture.Manager.DB.Models.MessagingExchange
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Manager.Messaging.ConnectionOptionsResolver

  @type qc :: {Queue.t, ConnectionOptions.t}

  @logprefix "[ResourceCache.Publisher]"

  @spec cache_clear(CachedResource.ct, any) :: :ok
  def cache_clear(type, key) do
    Logger.info "#{@logprefix} Publishing clear for #{type} #{key}"
    manager_components
    |> Enum.map(&(&1.messaging_exchange_id))
    |> Enum.uniq
    |> Enum.map(&__MODULE__.get_exchange_queue(&1))
    |> Enum.map(&publish_to_queue(&1, %{type: type, key: key}))
    Logger.info "#{@logprefix} Published clear for #{type} #{key}"
    :ok
  end

  @spec manager_components :: [map]
  defp manager_components do
    CachedResource.get(SystemComponent, :all, fn -> Repo.all(SystemComponent) end)
    |> Enum.filter(&(&1.type == "manager"))
  end

  @spec get_exchange_queue(integer) :: qc
  def get_exchange_queue(exchange_id), do: ConCache.get_or_store(:exchange_models_for_publisher, exchange_id, fn -> build_queue(exchange_id) end)

  @spec publish_to_queue(qc, any) :: :ok | {:error, String.t}
  defp publish_to_queue({queue, options}, payload), do: __MODULE__.publish(options, queue, payload)

  @spec build_queue(integer) :: qc
  defp build_queue(exchange_id) do
    Logger.info "#{@logprefix} Building queue for #{exchange_id}"
    queue = QueueBuilder.build_with_exchange("cache", Repo.get(MessagingExchange, exchange_id))
    options = ConnectionOptionsResolver.resolve(Configuration.get_current_broker_id,
                                                Configuration.get_current_exchange_id,
                                                exchange_id)
    {queue, options}
  end
end