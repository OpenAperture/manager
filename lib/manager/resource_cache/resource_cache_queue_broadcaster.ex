defmodule OpenAperture.Manager.ResourceCacheQueueBroadcaster do
  alias OpenAperture.Manager.Repo
  alias OpenAperture.ManagerApi
  require Repo


  @connection_options nil
  use OpenAperture.Messaging

  alias OpenAperture.Manager.Configuration
  alias OpenAperture.Manager.ResourceCache
  alias OpenAperture.Manager.DB.Models.SystemComponent
  alias OpenAperture.Messaging.AMQP.QueueBuilder
  alias OpenAperture.Messaging.ConnectionOptionsResolver

  def broadcast_cache_clear(type, key) do
    ResourceCache.get(:system_component, :all, fn -> Repo.all(SystemComponent) end)
    |> Enum.filter(&(&1.type == "manager"))
    |> Enum.map(&(&1.messaging_exchange_id))
    |> remove_duplicates
    |> Enum.map(&get_exchange_queue(&1))
    |> Enum.map(&broadcast_to_queue(&1, %{type: type, key: key}))
    IO.puts "Broadcasted clear for #{type} #{key}"
  end

  defp get_exchange_queue(exchange_id), do: ResourceCache.get(:exchange_cache_queues, exchange_id, fn -> build_queue(exchange_id) end)

  defp broadcast_to_queue({queue, options}, payload), do: __MODULE__.publish(options, queue, payload)

  defp build_queue(exchange_id) do
    queue = QueueBuilder.build(ManagerApi.get_api, "cache", exchange_id)
    options = ConnectionOptionsResolver.resolve(ManagerApi.get_api,
                                                Configuration.get_current_broker_id,
                                                Configuration.get_current_exchange_id,
                                                exchange_id)
    {queue, options}
  end

  defp remove_duplicates(list), do: Enum.reduce(list, [], &add_to_list(&1 in &2, &2, &1))

  defp add_to_list(false, list, item), do: [item] ++ list
  defp add_to_list(true, list, _item), do: list
end