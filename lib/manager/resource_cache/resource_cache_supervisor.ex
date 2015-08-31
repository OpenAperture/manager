defmodule OpenAperture.Manager.ResourceCacheSupervisor do
  use Supervisor

  alias OpenAperture.Manager.ResourceCache

  def start_link, do: Supervisor.start_link(__MODULE__, :ok)

  def init(:ok) do
    ResourceCache.cachable_types
    |> Enum.map(&create_con_cache_worker(&1))
    |> supervise(strategy: :one_for_one)
  end

  @con_cache_ttl [ttl_check: :timer.seconds(60*5), ttl: :timer.seconds(60*60)]

  def create_con_cache_worker(type), do: worker(ConCache, [@con_cache_ttl, [name: type]], [id: type])

end