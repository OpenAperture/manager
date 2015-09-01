defmodule OpenAperture.Manager.ResourceCache.RCSupervisor do
  use Supervisor

  alias OpenAperture.Manager.ResourceCache.CachedResource

  @spec start_link :: Supervisor.on_start
  def start_link, do: Supervisor.start_link(__MODULE__, :ok)

  @spec init(:ok) :: Supervisor.spec
  def init(:ok) do
    CachedResource.cachable_types
    |> Enum.map(&create_con_cache_worker(&1))
    |> supervise(strategy: :one_for_one)
  end

  @con_cache_ttl [ttl_check: :timer.seconds(60*5), ttl: :timer.seconds(60*60)]

  @spec create_con_cache_worker(CachedResource.ct) :: Supervisor.spec
  def create_con_cache_worker(type), do: worker(ConCache, [@con_cache_ttl, [name: type]], [id: type])

end