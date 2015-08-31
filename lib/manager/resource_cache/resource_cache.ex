require Logger

defmodule OpenAperture.Manager.ResourceCache do
  
  alias OpenAperture.Manager.ResourceCacheQueueBroadcaster

  def cachable_types, do: [:broker, :system_component, :exchange_cache_queues]

  def get(type, key, get_fun) do
    Logger.debug "ResourceCache: #{type} #{key} Get"
    type
    |> validate_type
    |> ConCache.get_or_store(key, fn -> Logger.debug("ResourceCache: #{type} #{key} Cache Miss"); get_fun.() end)
  end

  def clear(type, key) do
    ResourceCacheQueueBroadcaster.broadcast_cache_clear(type, key)
    Logger.debug "ResourceCache: #{type} #{key} Cache Clear"
    clear_local(type, key)
  end

  def clear_local(type, key) do
    type
    |> validate_type
    |> ConCache.delete(key)
    ConCache.delete(type, :all)
  end

  def wipe_all_caches, do: Enum.map(cachable_types, &wipe_all_cache/1)

  def wipe_all_cache(type) do
    type
    |> ConCache.ets
    |> :ets.tab2list
    |> Enum.each(fn({key, _}) -> ConCache.delete(type, key) end)
  end

  defp validate_type(type) do
    __MODULE__.cachable_types
    |> Enum.filter(fn t -> t == type end)
    |> length
    |> check_valid_length(type)
  end

  defp check_valid_length(0, _type), do: raise "Invalid cache type"
  defp check_valid_length(_len, type), do: type

end