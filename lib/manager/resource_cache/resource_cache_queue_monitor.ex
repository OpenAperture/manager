require Logger

defmodule OpenAperture.Manager.ResourceCacheQueueMonitor do
  use GenServer

  alias OpenAperture.Manager.ResourceCache

  @spec start_link() :: GenServer.on_start
  def start_link() do
    if Application.get_env(OpenAperture.Manager, :cache_queue_monitor_autostart, false) do
      Logger.debug("[ResourceCacheQueueMonitor] Starting...")
        case GenServer.start_link(__MODULE__, :ok, name: __MODULE__) do
        {:ok, pid} ->
          Logger.debug("[ResourceCacheQueueMonitor] Startup Complete")
          {:ok, pid}
        {:error, reason} -> {:error, reason}
      end
    else
      Logger.debug("[ResourceCacheQueueMonitor] skipping startup: autostart disabled")
      Agent.start_link(fn -> nil end) #to return {:ok, pid} to the supervisor
    end
  end

  @spec init(:ok) :: {:ok, nil}
  def init(:ok) do
    OpenAperture.Manager.ManagerQueueSubscriber.subscribe_manager_queue("cache", &clear_cache/1)
    {:ok, nil}
  end

  @spec clear_cache(term) :: :ok | {:error, term}
  def clear_cache(%{type: type, key: key}), do: ResourceCache.clear_local(type, key)
end