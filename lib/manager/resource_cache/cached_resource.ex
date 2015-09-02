require Logger

defmodule OpenAperture.Manager.ResourceCache.CachedResource do
  
  alias OpenAperture.Manager.ResourceCache.Publisher

  alias OpenAperture.Manager.DB.Models.MessagingBroker
  alias OpenAperture.Manager.DB.Models.SystemComponent

  @logprefix "[ResourceCache.CachedResource]"

  @type ct :: MessagingBroker | SystemComponent | :exchange_cache_queues
  def cachable_types, do: [MessagingBroker, SystemComponent, :exchange_cache_queues]

  @spec get(ct, any, fun) :: any
  def get(type, key, get_fun) do
    Logger.debug "#{@logprefix} #{type} #{key} Get"
    type
    |> validate_type
    |> ConCache.get_or_store(key, fn -> Logger.debug("#{@logprefix} #{type} #{key} Cache Miss"); get_fun.() end)
  end

  @spec clear(ct, any) :: :ok
  def clear(type, key) do
    Publisher.cache_clear(type, key)
    Logger.debug "#{@logprefix} #{type} #{key} Cache Clear"
    clear_local(type, key)
  end

  @spec clear_local(ct, any) :: :ok
  def clear_local(type, key) do
    type
    |> validate_type
    |> ConCache.delete(key)
    ConCache.delete(type, :all)
  end

  @spec validate_type(ct) :: ct
  defp validate_type(type) do
    cond do
      type in cachable_types -> type
      true -> raise "Invalid cache type"
    end
  end

end