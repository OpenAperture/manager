require Logger

defmodule OpenAperture.Manager.ResourceCache do
  
  alias OpenAperture.Manager.ResourceCacheQueueBroadcaster

  @type ct :: :broker | :system_component | :exchange_cache_queues
  def cachable_types, do: [:broker, :system_component, :exchange_cache_queues]

  @spec get(ct, any, fun) :: any
  def get(type, key, get_fun) do
    Logger.debug "ResourceCache: #{type} #{key} Get"
    type
    |> validate_type
    |> ConCache.get_or_store(key, fn -> Logger.debug("ResourceCache: #{type} #{key} Cache Miss"); get_fun.() end)
  end

  @spec clear(ct, any) :: :ok
  def clear(type, key) do
    ResourceCacheQueueBroadcaster.broadcast_cache_clear(type, key)
    Logger.debug "ResourceCache: #{type} #{key} Cache Clear"
    clear_local(type, key)
  end

  @spec clear_local(ct, any) :: :ok
  def clear_local(type, key) do
    type
    |> validate_type
    |> ConCache.delete(key)
    ConCache.delete(type, :all)
  end

  @spec wipe_all_caches :: [:ok]
  def wipe_all_caches, do: Enum.map(cachable_types, &wipe_all_cache/1)

  @spec wipe_all_cache(any) :: :ok
  def wipe_all_cache(type) do
    type
    |> ConCache.ets
    |> :ets.tab2list
    |> Enum.each(fn({key, _}) -> ConCache.delete(type, key) end)
    :ok
  end

  @spec validate_type(ct) :: ct
  defp validate_type(type) do
    __MODULE__.cachable_types
    |> Enum.filter(fn t -> t == type end)
    |> length
    |> check_valid_length(type)
  end

  @spec check_valid_length(non_neg_integer, ct) :: ct
  defp check_valid_length(0, _type), do: raise "Invalid cache type"
  defp check_valid_length(_len, type), do: type

end