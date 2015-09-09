ExUnit.start

defmodule CacheWipe do
  @spec wipe_all_caches :: [:ok]
  def wipe_all_caches, do: Enum.map(OpenAperture.Manager.ResourceCache.Registry.get_all_active_cache_types, &wipe_all_cache/1)

  @spec wipe_all_cache(any) :: :ok
  def wipe_all_cache(type) do
    type
    |> ConCache.ets
    |> :ets.tab2list
    |> Enum.each(fn({key, _}) -> ConCache.delete(type, key) end)
    :ok
  end
end