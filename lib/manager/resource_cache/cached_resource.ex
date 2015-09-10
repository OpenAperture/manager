require Logger
defmodule OpenAperture.Manager.ResourceCache.CachedResource do
  use GenServer

  alias OpenAperture.Manager.ResourceCache.Publisher
  alias OpenAperture.Manager.ResourceCache.Registry, as: CacheRegistry

  @logprefix "[ResourceCache.CachedResource]"

  @spec get(atom, any, fun) :: any
  def get(type, key, get_fun), do: _get(type, key, get_fun, __MODULE__.cache_disabled)

  @spec _get(atom, any, fun, boolean) :: any
  defp _get(_type, _key, get_fun, true), do: get_fun.()
  defp _get(type, key, get_fun, false) do
    Logger.info "#{@logprefix} #{type} #{key} Get"
    type
    |> validate_type
    |> CacheRegistry.verify_started
    |> ConCache.get_or_store(key, fn -> Logger.info("#{@logprefix} #{type} #{key} Cache Miss"); get_fun.() end)
  end

  @spec clear(atom, any) :: :ok
  def clear(type, key), do: _clear(type, key, __MODULE__.cache_disabled)

  @spec _clear(atom, any, boolean) :: :ok
  def _clear(_type, _key, true), do: :ok
  def _clear(type, key, false) do
    Logger.info "#{@logprefix} #{type} #{key} Cache Clear"
    type
    |> validate_type
    |> Publisher.cache_clear(key)
  end

  @spec cache_disabled :: boolean
  def cache_disabled, do: Application.get_env(OpenAperture.Manager, :disable_cache, false)

  @spec validate_type(atom) :: atom
  def validate_type(type), do: raise_if_invalid(type, :erlang.function_exported(type, :cachable_type, 0) && apply(type, :cachable_type, []))

  @spec raise_if_invalid(atom, boolean) :: atom
  defp raise_if_invalid(type, true), do: type
  defp raise_if_invalid(type, false), do: raise "Invalid cache type: #{type}"

end